import 'package:hexadci_example/features/assess_late_fees/assess_late_fees.dart';
import 'package:hexadci_example/features/assess_late_fees/customers.dart';
import 'package:hexadci_example/features/assess_late_fees/late_fee_invoices.dart';
import 'package:hexadci_example/features/assess_late_fees/retrieve_deposits.dart';
import 'package:hexadci_example/ports/bank.dart';
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  final customer = DirectCustomer(account(), const NullLateFeeNotice());

  // (description, balance cents, fee cents)
  const feeRules = [
    ('1.5% of the balance', 100000, 1500),
    ('never less than \$5.00', 20000, 500),
    ('half a cent rounds up', 50100, 752),
    ('under half a cent rounds down', 50033, 750),
  ];
  for (final (description, balance, fee) in feeRules) {
    test('late fee: $description', () {
      expect(ChargeableInvoice(invoice(balanceCents: balance), customer).lateFeeCents, fee);
    });
  }

  test('payment-plan invoices are never due', () {
    expect(PaymentPlanInvoice(invoice(daysPastDue: 365), customer).ifDueForLateFee(today), isNull);
  });

  Future<List<Deposit>> deposits(List<RawDeposit> raw) =>
      RetrieveDeposits.call(bank: FakeBank({'acct-1': raw}), bankAccountNumber: 'acct-1');

  test("translates the bank's fields into ours", () async {
    final [translated] = await deposits([deposit(amt: '125.5', memo: 'INV 7', sts: 'PND')]);

    expect(translated.amountCents, 12550);
    expect(translated.memo, 'INV 7');
    expect(translated.cleared, isFalse);
  });

  test('whole-dollar amounts', () async {
    expect((await deposits([deposit(amt: '125')])).single.amountCents, 12500);
  });

  test("keeps the bank's transaction id", () async {
    expect((await deposits([deposit(txnId: 'T-42')])).single.transactionId, 'T-42');
  });

  test('refuses what it cannot read', () async {
    for (final raw in [deposit(amt: '12.345'), deposit(amt: '-5.00'), deposit(sts: 'XYZ'), deposit(txnId: '')]) {
      await expectLater(deposits([raw]), throwsA(isA<UnrecognizedDeposit>()), reason: '$raw');
    }
  });

  test('impossible runs throw', () {
    final changedWhileDown = Run()
      ..bankUnavailable = 'down'
      ..lateFees.add(('A-1', 1500));
    final belowMinimum = Run()..lateFees.add(('A-1', 100));
    final changedTwice = Run()
      ..lateFees.add(('A-1', 1500))
      ..foundPaid.add('A-1');

    for (final run in [changedWhileDown, belowMinimum, changedTwice]) {
      expect(run.checkTotals, throwsA(isA<ImpossibleRun>()));
    }
  });

  test('a reported repeat is not an impossible run', () {
    final run = Run()
      ..lateFees.add(('A-1', 1500))
      ..notProcessed.add(('A-1', 'listed more than once in this run'));

    expect(run.checkTotals, returnsNormally);
  });
}
