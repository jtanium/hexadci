import 'dart:math';

import '../../records/records.dart';
import 'customers.dart';
import 'invoice_record_facts.dart';
import 'retrieve_deposits.dart';

const daysPastDueBeforeAFee = 30;
const daysBetweenFees = 30;
const minimumFeeCents = 500;

/// The invoice, in one of the roles it can play in assessing late fees. Every
/// role shares its number, its customer, and the notices owed for fees already
/// added.
sealed class LateFeeInvoice {
  final InvoiceRecord _record;
  final Customer customer;

  LateFeeInvoice(this._record, this.customer);

  String get number => _record.number ?? '';

  /// This invoice as a chargeable invoice, if it is due a late fee today;
  /// otherwise null. Lets the context select due invoices without checking
  /// which role each one plays.
  ChargeableInvoice? ifDueForLateFee(DateTime on);

  List<LateFee> unsentLateFees() => [
        for (final fee in _record.lateFees)
          if (!fee.noticeSent) fee
      ];

  Future<void> markNoticeSent(LateFee fee) {
    fee.noticeSent = true;
    return _record.save();
  }

  InvoiceRecord unwrap() => _record;
}

/// The invoice, in the role of "an open invoice that may owe a late fee".
final class ChargeableInvoice extends LateFeeInvoice {
  ChargeableInvoice(super.record, super.customer);

  /// An invoice owes a late fee once it is more than 30 days past due, and
  /// then at most once every 30 days, so a customer is never charged twice for
  /// the same month of lateness. (Business rule R1.)
  @override
  ChargeableInvoice? ifDueForLateFee(DateTime on) =>
      _record.moreThan30DaysPastDue(on) && _record.noLateFeeInTheLast30Days(on) ? this : null;

  /// A late fee is 1.5% of what the customer owes, but never less than $5.00,
  /// so small balances still carry a meaningful fee. Half a cent rounds up.
  /// (Business rule R3.)
  int get lateFeeCents => max(_record.oneAndAHalfPercentOfTheBalance, minimumFeeCents);

  /// A customer who has already paid should not be charged a fee. The invoice
  /// counts as paid when a cleared deposit names it and covers the balance. A
  /// pending deposit does not count yet. One bank transaction can pay only one
  /// invoice, even when the bank reports it for two customers who share an
  /// account. (Business rule R4.)
  Deposit? coveringDeposit(List<Deposit> deposits, {required Set<String> alreadyApplied}) {
    for (final deposit in deposits) {
      if (deposit.cleared &&
          _record.coveredBy(deposit) &&
          _record.namedIn(deposit) &&
          !alreadyApplied.contains(deposit.transactionId)) {
        return deposit;
      }
    }
    return null;
  }

  Future<LateFee> addLateFee(int feeCents, {required DateTime on}) async {
    final fee = LateFee(amountCents: feeCents, assessedOn: on);
    _record.lateFees.add(fee);
    // DECISION D1: the fee becomes part of what the customer owes, so later fees
    // are figured on it and a deposit must cover it too. Confirm with Finance.
    _record.balanceCents += feeCents;
    await _record.save();
    return fee;
  }

  Future<void> markPaid() {
    _record.status = InvoiceStatus.paid;
    return _record.save();
  }
}

/// Customers on a payment plan have already agreed a schedule with Finance,
/// so they never get late fees, and their invoices are not even checked at the
/// bank. (Business rule R2.)
final class PaymentPlanInvoice extends LateFeeInvoice {
  PaymentPlanInvoice(super.record, super.customer);

  @override
  ChargeableInvoice? ifDueForLateFee(DateTime on) => null;
}
