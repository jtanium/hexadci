// Demo data standing in for the database and the bank, so the entry points run.
import 'package:hex_dci_example/ports/bank.dart';
import 'package:hex_dci_example/records/records.dart';

final today = DateTime.utc(2026, 10, 29);

DateTime _daysAgo(int days) => today.subtract(Duration(days: days));

const accounts = [
  Account(id: 1, name: 'Example Coffee', companyEmail: 'ap@coffee.test', bankAccountNumber: '000111'),
  Account(
      id: 2,
      name: 'Resold Bakery',
      billedThroughReseller: true,
      resellerEmail: 'billing@reseller.test',
      bankAccountNumber: '000222'),
  Account(id: 3, name: 'Planned Books', onPaymentPlan: true, bankAccountNumber: '000333'),
];

List<InvoiceRecord> openInvoices() => [
      InvoiceRecord(1, number: '2026-0412', dueDate: _daysAgo(45), balanceCents: 100000, status: InvoiceStatus.open),
      InvoiceRecord(1, number: '2026-0415', dueDate: _daysAgo(40), balanceCents: 12000, status: InvoiceStatus.open),
      InvoiceRecord(2, number: '2026-0420', dueDate: _daysAgo(35), balanceCents: 20000, status: InvoiceStatus.open),
      InvoiceRecord(3, number: '2026-0431', dueDate: _daysAgo(90), balanceCents: 50000, status: InvoiceStatus.open),
    ];

class DemoBank implements Bank {
  static const _deposits = {
    '000111': [
      {'txn_id': 'T-1001', 'amt': '120.00', 'memo_txt': 'INV 2026-0415 thanks', 'posted': '20261027', 'sts': 'CLR'},
    ],
  };

  @override
  Future<List<RawDeposit>> recentDeposits(String bankAccountNumber) async => _deposits[bankAccountNumber] ?? [];
}
