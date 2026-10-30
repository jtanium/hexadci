import '../../ports/bank.dart';
import 'customers.dart';
import 'errors.dart';
import 'late_fee_invoices.dart';
import 'retrieve_deposits.dart';

/// Checking the bank means: fetch recent deposits for every customer with an
/// invoice due a late fee, before anything is changed.
///
/// BankUnavailable is deliberately not caught: the context decides what an
/// outage means for the run. An unreadable deposit only affects that customer,
/// so it is kept and thrown when their deposits are asked for.
class CheckBank {
  static Future<BankCheck> call({required List<ChargeableInvoice> invoices, required Bank bank}) async {
    final customers = {for (final invoice in invoices) invoice.customer.id: invoice.customer};
    final deposits = <int, Object>{};
    for (final MapEntry(key: id, value: customer) in customers.entries) {
      deposits[id] = await _depositsFor(customer, bank);
    }
    return BankCheck._(deposits);
  }

  static Future<Object> _depositsFor(Customer customer, Bank bank) async {
    try {
      return await RetrieveDeposits.call(bank: bank, bankAccountNumber: customer.bankAccountNumber);
    } on UnrecognizedDeposit catch (problem) {
      return problem;
    }
  }
}

class BankCheck {
  final Map<int, Object> _depositsByCustomerId; // List<Deposit> or the RecordProblem for that customer

  BankCheck._(this._depositsByCustomerId);

  List<Deposit> depositsFor(Customer customer) => switch (_depositsByCustomerId[customer.id]) {
        final List<Deposit> deposits => deposits,
        final RecordProblem problem => throw problem,
        _ => throw StateError('customer ${customer.id} was not checked at the bank'),
      };
}
