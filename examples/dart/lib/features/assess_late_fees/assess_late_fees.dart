/// Assess late fees on overdue invoices.
library;

import '../../ports/bank.dart';
import '../../records/records.dart';
import 'check_bank.dart';
import 'customers.dart';
import 'errors.dart';
import 'late_fee_invoices.dart';
import 'late_fee_notice.dart';
import 'listener.dart';
import 'run.dart';

export 'errors.dart';
export 'late_fee_notice.dart';
export 'listener.dart';
export 'run.dart';

/// Assess late fees on a set of open invoices. The nightly job passes every
/// open invoice; the single-account CLI passes one account's. Same rules.
class AssessLateFees {
  final Bank _bank;
  final DateTime _on;
  final AssessLateFeesListener _listener;
  final Run _run = Run();
  final Set<String> _appliedTransactionIds = {};
  final List<InvoiceRecord> _repeats;
  final List<InvoiceRecord> _uncastable;
  final List<LateFeeInvoice> _invoices;

  // `notice` has no default: telling the customer is required (R6).
  // The listener is diagnostic, so it defaults to doing nothing.
  static Future<Run> call({
    required List<InvoiceRecord> invoices,
    required List<Account> accounts,
    required Bank bank,
    required LateFeeNotice notice,
    DateTime? on,
    AssessLateFeesListener listener = const NullAssessLateFeesListener(),
  }) {
    // An invoice listed twice is still only one invoice: handle it once and
    // report the repeat, before anything can be charged or sent. (Business rule R8.)
    final seen = <String?>{};
    final unique = <InvoiceRecord>[];
    final repeats = <InvoiceRecord>[];
    for (final record in invoices) {
      (seen.add(record.number) ? unique : repeats).add(record);
    }

    final customers = {for (final account in accounts) account.id: _castCustomer(account, notice)};
    return AssessLateFees._(
      bank: bank,
      on: on ?? DateTime.now(),
      listener: listener,
      repeats: repeats,
      uncastable: [for (final record in unique) if (!customers.containsKey(record.accountId)) record],
      invoices: [
        for (final record in unique)
          if (customers[record.accountId] case final customer?) _castInvoice(record, customer),
      ],
    )._assess();
  }

  AssessLateFees._({
    required Bank bank,
    required DateTime on,
    required AssessLateFeesListener listener,
    required List<InvoiceRecord> repeats,
    required List<InvoiceRecord> uncastable,
    required List<LateFeeInvoice> invoices,
  })  : _bank = bank,
        _on = on,
        _listener = listener,
        _repeats = repeats,
        _uncastable = uncastable,
        _invoices = invoices;

  // To assess late fees:
  //   1. report any invoice whose account we cannot find, or that is listed more
  //      than once; carry on with the rest
  //   2. send any late-fee notice from an earlier run that did not go out
  //   3. pick the invoices due a late fee today
  //   4. check the bank for every customer with such an invoice, before
  //      changing anything; if the bank is down, charge nobody tonight
  //   5. for each due invoice: if a cleared deposit already covers it, mark it
  //      paid; otherwise add a late fee and tell whoever handles the customer's
  //      billing. One bad invoice does not stop the others
  //   6. sanity-check the results and report the summary
  Future<Run> _assess() async {
    for (final record in _repeats) {
      _notProcessed(record.number ?? '', 'listed more than once in this run');
    }
    for (final record in _uncastable) {
      _notProcessed(record.number ?? '', 'no account ${record.accountId}');
    }

    await _sendEarlierNotices();

    final due = _invoices.map((invoice) => invoice.ifDueForLateFee(_on)).nonNulls.toList();

    final BankCheck bankCheck;
    try {
      bankCheck = await CheckBank.call(invoices: due, bank: _bank);
    } on BankUnavailable catch (outage) {
      // Without the bank we can't tell who has already paid, so nobody is
      // charged or marked paid tonight. (Business rule R5.)
      _run.bankUnavailable = outage.message;
      _listener.bankUnavailable(outage.message);
      return _finish();
    }

    for (final invoice in due) {
      await _settle(invoice, bankCheck);
    }

    return _finish();
  }

  Future<void> _sendEarlierNotices() async {
    // A customer charged a fee must hear about it. A notice that failed is sent
    // again on every run until it goes out. (Business rule R9.)
    for (final invoice in _invoices) {
      for (final fee in invoice.unsentLateFees()) {
        if (await _tellCustomer(invoice, fee)) {
          _run.earlierNoticesSent.add(invoice.number);
          _listener.earlierNoticeSent(invoice.unwrap(), fee.amountCents);
        }
      }
    }
  }

  Future<void> _settle(ChargeableInvoice invoice, BankCheck bankCheck) async {
    try {
      final deposit =
          invoice.coveringDeposit(bankCheck.depositsFor(invoice.customer), alreadyApplied: _appliedTransactionIds);
      if (deposit != null) {
        await invoice.markPaid();
        _appliedTransactionIds.add(deposit.transactionId);
        _run.foundPaid.add(invoice.number);
        _listener.invoiceFoundPaid(invoice.unwrap());
      } else {
        final fee = await invoice.addLateFee(invoice.lateFeeCents, on: _on);
        _run.lateFees.add((invoice.number, fee.amountCents));
        _listener.lateFeeAdded(invoice.unwrap(), fee.amountCents);
        await _tellCustomer(invoice, fee);
      }
    } on RecordProblem catch (problem) {
      // One invoice's problem is reported and the others carry on. (Business rule R7.)
      _notProcessed(invoice.number, problem.message);
    }
  }

  Future<bool> _tellCustomer(LateFeeInvoice invoice, LateFee fee) async {
    try {
      await invoice.customer.notifyOfLateFee(invoice.unwrap(), fee.amountCents);
    } on NoticeFailed catch (failure) {
      // The fee stands; the notice stays unsent and is retried next run (R9).
      _run.warnings.add((invoice.number, 'late fee notice failed, will retry next run: ${failure.message}'));
      _listener.lateFeeNoticeFailed(invoice.unwrap(), failure.message);
      return false;
    }
    await invoice.markNoticeSent(fee);
    return true;
  }

  void _notProcessed(String number, String reason) {
    _run.notProcessed.add((number, reason));
    _listener.invoiceNotProcessed(number, reason);
  }

  Run _finish() {
    _run.checkTotals();
    _listener.runFinished(_run);
    return _run; // control our return value
  }

  static Customer _castCustomer(Account account, LateFeeNotice notice) =>
      account.billedThroughReseller ? ResellerCustomer(account, notice) : DirectCustomer(account, notice);

  static LateFeeInvoice _castInvoice(InvoiceRecord record, Customer customer) =>
      customer.onPaymentPlan ? PaymentPlanInvoice(record, customer) : ChargeableInvoice(record, customer);
}
