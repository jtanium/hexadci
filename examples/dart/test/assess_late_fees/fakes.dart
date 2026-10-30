import 'package:hex_dci_example/features/assess_late_fees/assess_late_fees.dart';
import 'package:hex_dci_example/ports/bank.dart';
import 'package:hex_dci_example/records/records.dart';

final today = DateTime.utc(2026, 10, 29);

DateTime daysAgo(int days) => today.subtract(Duration(days: days));

/// Answers with the bank's own record format. Never a null object: tests say
/// exactly what the bank returns, or that it is down.
class FakeBank implements Bank {
  final Map<String, List<RawDeposit>> deposits;
  final bool down;
  final askedAbout = <String>[];

  FakeBank([this.deposits = const {}, this.down = false]);

  FakeBank.down() : this(const {}, true);

  @override
  Future<List<RawDeposit>> recentDeposits(String bankAccountNumber) async {
    askedAbout.add(bankAccountNumber);
    if (down) throw BankUnavailable('bank is down');
    return deposits[bankAccountNumber] ?? [];
  }
}

class FakeNotice implements LateFeeNotice {
  bool failing;
  final sent = <({String to, String? number, int feeCents})>[];

  FakeNotice({this.failing = false});

  @override
  Future<void> lateFeeAdded({required String to, required InvoiceRecord invoice, required int feeCents}) async {
    if (failing) throw NoticeFailed('mail server refused');
    sent.add((to: to, number: invoice.number, feeCents: feeCents));
  }
}

class RecordingListener implements AssessLateFeesListener {
  final events = <(String, List<Object?>)>[];

  List<String> get names => [for (final (name, _) in events) name];

  @override
  void invoiceNotProcessed(String number, String reason) => events.add(('invoiceNotProcessed', [number, reason]));
  @override
  void lateFeeAdded(InvoiceRecord invoice, int feeCents) => events.add(('lateFeeAdded', [invoice, feeCents]));
  @override
  void invoiceFoundPaid(InvoiceRecord invoice) => events.add(('invoiceFoundPaid', [invoice]));
  @override
  void lateFeeNoticeFailed(InvoiceRecord invoice, String reason) => events.add(('lateFeeNoticeFailed', [invoice, reason]));
  @override
  void earlierNoticeSent(InvoiceRecord invoice, int feeCents) => events.add(('earlierNoticeSent', [invoice, feeCents]));
  @override
  void bankUnavailable(String reason) => events.add(('bankUnavailable', [reason]));
  @override
  void runFinished(Run run) => events.add(('runFinished', [run]));
}

Account account({
  int id = 1,
  bool billedThroughReseller = false,
  String? resellerEmail,
  bool onPaymentPlan = false,
  String? bankAccountNumber,
}) =>
    Account(
      id: id,
      name: 'Account $id',
      companyEmail: 'ap$id@example.test',
      bankAccountNumber: bankAccountNumber ?? 'acct-$id',
      billedThroughReseller: billedThroughReseller,
      resellerEmail: resellerEmail,
      onPaymentPlan: onPaymentPlan,
    );

InvoiceRecord invoice({
  String number = '2026-0412',
  int accountId = 1,
  int daysPastDue = 45,
  int balanceCents = 100000,
  int? lastFeeDaysAgo,
}) {
  final record = InvoiceRecord(accountId,
      number: number, dueDate: daysAgo(daysPastDue), balanceCents: balanceCents, status: InvoiceStatus.open);
  if (lastFeeDaysAgo != null) {
    record.lateFees.add(LateFee(amountCents: 500, assessedOn: daysAgo(lastFeeDaysAgo), noticeSent: true));
  }
  return record;
}

RawDeposit deposit({String amt = '1000.00', String memo = 'INV 2026-0412', String sts = 'CLR', String txnId = 'T-1'}) =>
    {'txn_id': txnId, 'amt': amt, 'memo_txt': memo, 'posted': '20261027', 'sts': sts};
