import 'package:hexadci_example/features/assess_late_fees/assess_late_fees.dart';
import 'package:hexadci_example/records/records.dart';
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  late FakeBank bank;
  late FakeNotice notice;
  late RecordingListener listener;

  setUp(() {
    bank = FakeBank();
    notice = FakeNotice();
    listener = RecordingListener();
  });

  Future<Run> assess(List<InvoiceRecord> invoices, [List<Account>? accounts]) => AssessLateFees.call(
      invoices: invoices, accounts: accounts ?? [account()], bank: bank, notice: notice, on: today, listener: listener);

  // (description, invoice, account, charged?)
  final whoIsCharged = [
    ('more than 30 days past due', invoice(daysPastDue: 31), account(), true),
    ('exactly 30 days past due', invoice(daysPastDue: 30), account(), false),
    ('last fee only 10 days ago', invoice(daysPastDue: 90, lastFeeDaysAgo: 10), account(), false),
    ('last fee 30 days ago', invoice(daysPastDue: 90, lastFeeDaysAgo: 30), account(), true),
    ('customer on a payment plan', invoice(daysPastDue: 90), account(onPaymentPlan: true), false),
  ];
  for (final (description, record, acct, charged) in whoIsCharged) {
    test('who is charged: $description', () async {
      final run = await assess([record], [acct]);
      expect(run.lateFees, hasLength(charged ? 1 : 0));
    });
  }

  // (description, deposits at the bank, found paid?)
  final bankCases = [
    ('cleared deposit covering the balance', [deposit(amt: '1000.00')], true),
    ('cleared deposit over the balance', [deposit(amt: '1500.00')], true),
    ('cleared deposit short of the balance', [deposit(amt: '999.99')], false),
    ('pending deposit covering the balance', [deposit(sts: 'PND')], false),
    ('deposit for another invoice', [deposit(memo: 'INV 2026-0999')], false),
    ('memo with a longer number containing ours', [deposit(memo: 'INV 2026-04120')], false),
  ];
  for (final (description, deposits, paid) in bankCases) {
    test('bank check before charging: $description', () async {
      bank = FakeBank({'acct-1': deposits});
      final record = invoice();
      final run = await assess([record]);

      expect(run.foundPaid, paid ? ['2026-0412'] : isEmpty);
      expect(record.status, paid ? InvoiceStatus.paid : InvoiceStatus.open);
      expect(run.lateFees, hasLength(paid ? 0 : 1));
    });
  }

  test('a late fee is added and the billing contact told', () async {
    final record = invoice(balanceCents: 100000);
    final run = await assess([record]);

    expect(run.lateFees, [('2026-0412', 1500)]);
    expect(record.balanceCents, 101500);
    expect(notice.sent, [(to: 'ap1@example.test', number: '2026-0412', feeCents: 1500)]);
  });

  test('the reseller is told instead of the customer', () async {
    await assess([invoice()], [account(billedThroughReseller: true, resellerEmail: 'billing@reseller.test')]);
    expect(notice.sent.map((n) => n.to), ['billing@reseller.test']);
  });

  test('bank down means nobody is charged or marked paid', () async {
    bank = FakeBank.down();
    final records = [invoice(number: 'A-1'), invoice(number: 'B-2', accountId: 2)];

    final run = await assess(records, [account(id: 1), account(id: 2)]);

    expect(run.bankUnavailable, 'bank is down');
    expect(run.lateFees, isEmpty);
    expect(records.every((r) => r.status == InvoiceStatus.open && r.lateFees.isEmpty), isTrue);
    expect(notice.sent, isEmpty);
    expect(listener.names, ['bankUnavailable', 'runFinished']);
  });

  test('payment-plan customers are never checked at the bank', () async {
    bank = FakeBank.down();
    final run = await assess([invoice(daysPastDue: 90)], [account(onPaymentPlan: true)]);

    expect(bank.askedAbout, isEmpty);
    expect(run.bankUnavailable, isNull);
  });

  test('an unreadable deposit stops that customer only', () async {
    bank = FakeBank({'acct-1': [deposit(amt: 'twelve')], 'acct-2': []});
    final run = await assess(
        [invoice(number: 'A-1'), invoice(number: 'B-2', accountId: 2)], [account(id: 1), account(id: 2)]);

    expect(run.notProcessed.map((n) => n.$1), ['A-1']);
    expect(run.notProcessed.first.$2, contains('could not read deposit'));
    expect(run.lateFees.map((f) => f.$1), ['B-2']);
  });

  test('a failed notice is a warning and the fee stands', () async {
    notice = FakeNotice(failing: true);
    final record = invoice();
    final run = await assess([record]);

    expect(record.lateFees, hasLength(1));
    expect(run.warnings.map((w) => w.$1), ['2026-0412']);
    expect(listener.names, contains('lateFeeNoticeFailed'));
  });

  test('an invoice without an account is reported and the rest continue', () async {
    final run = await assess([invoice(number: 'ORPHAN', accountId: 99), invoice(number: 'A-1')]);

    expect(run.notProcessed, [('ORPHAN', 'no account 99')]);
    expect(run.lateFees.map((f) => f.$1), ['A-1']);
  });

  test('one deposit pays one invoice', () async {
    bank = FakeBank({'acct-1': [deposit(memo: '2026-0412 2026-0413')]});
    final run = await assess([invoice(number: '2026-0412'), invoice(number: '2026-0413')]);

    expect(run.foundPaid, ['2026-0412']);
    expect(run.lateFees.map((f) => f.$1), ['2026-0413']);
  });

  test('an invoice listed twice is charged and notified once', () async {
    final record = invoice(balanceCents: 100000);

    final run = await assess([record, record]);

    expect(run.lateFees, [('2026-0412', 1500)]);
    expect(record.balanceCents, 101500);
    expect(notice.sent, hasLength(1));
    expect(run.notProcessed, [('2026-0412', 'listed more than once in this run')]);
  });

  test('one transaction pays one invoice even when customers share a bank account', () async {
    const shared = 'shared-acct';
    bank = FakeBank({
      shared: [deposit(memo: '2026-0412 2026-0413', txnId: 'T-77')]
    });
    final records = [invoice(number: '2026-0412', accountId: 1), invoice(number: '2026-0413', accountId: 2)];

    final run = await assess(
        records, [account(id: 1, bankAccountNumber: shared), account(id: 2, bankAccountNumber: shared)]);

    expect(run.foundPaid, ['2026-0412']);
    expect(run.lateFees.map((f) => f.$1), ['2026-0413']);
  });

  test('a failed notice is sent on the next run', () async {
    final record = invoice();
    notice = FakeNotice(failing: true);
    final first = await assess([record]);
    expect(first.warnings.map((w) => w.$1), ['2026-0412']);
    expect(record.lateFees.first.noticeSent, isFalse);

    notice.failing = false;
    listener = RecordingListener();
    final second = await assess([record]);

    expect(second.lateFees, isEmpty); // not charged again: the last fee was today
    expect(second.earlierNoticesSent, ['2026-0412']);
    expect(notice.sent, [(to: 'ap1@example.test', number: '2026-0412', feeCents: 1500)]);
    expect(record.lateFees.first.noticeSent, isTrue);
    expect(listener.names, contains('earlierNoticeSent'));
  });

  test('a notice that keeps failing is reported again each run', () async {
    final record = invoice();
    notice = FakeNotice(failing: true);
    await assess([record]);

    final second = await assess([record]);

    expect(second.warnings.map((w) => w.$1), ['2026-0412']);
    expect(record.lateFees.first.noticeSent, isFalse);
  });

  test('earlier notices go out even when the bank is down', () async {
    final record = invoice();
    record.lateFees.add(LateFee(amountCents: 1500, assessedOn: today)); // notice never sent
    bank = FakeBank.down();

    final run = await assess([record]);

    expect(run.earlierNoticesSent, ['2026-0412']);
    expect(run.lateFees, isEmpty);
  });

  test('programming errors are not hidden as record problems', () async {
    final broken = invoice()..dueDate = null; // a bug upstream, not bad customer data

    await expectLater(assess([broken]), throwsA(isA<Error>()));
  });

  test('returns the run and reports it', () async {
    final run = await assess([invoice()]);
    final (name, args) = listener.events.last;
    expect(name, 'runFinished');
    expect(args.single, same(run));
  });
}
