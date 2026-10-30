import '../../records/records.dart';
import 'late_fee_invoices.dart';
import 'retrieve_deposits.dart';

final _token = RegExp(r'[A-Za-z0-9-]+');

/// How our records answer the late-fee rules' questions: dates, money, and memo
/// text. These are implementation details, not policy; the policy (how many
/// days, the minimum fee) lives with the rules in late_fee_invoices.dart.
///
/// A named extension adds these to [InvoiceRecord] only where this file is
/// imported, and needs no role state, so it suits facts about the record itself.
extension LateFeeFacts on InvoiceRecord {
  bool moreThan30DaysPastDue(DateTime on) =>
      // A missing due date is a bug upstream, not bad customer data, so it throws.
      on.difference(dueDate!).inDays > daysPastDueBeforeAFee;

  bool noLateFeeInTheLast30Days(DateTime on) =>
      lateFees.every((fee) => on.difference(fee.assessedOn).inDays >= daysBetweenFees);

  int get oneAndAHalfPercentOfTheBalance => (balanceCents * 15 + 500) ~/ 1000; // rounding half a cent up

  bool coveredBy(Deposit deposit) => deposit.amountCents >= balanceCents;

  bool namedIn(Deposit deposit) =>
      _token.allMatches(deposit.memo).any((m) => m.group(0)!.toLowerCase() == (number ?? '').toLowerCase());
}
