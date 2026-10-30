/// Invoice an account for its uninvoiced charges.
library;

import '../../ports/notifier.dart';
import '../../records/records.dart';
import 'billable_accounts.dart';
import 'build_invoice.dart';
import 'draft_invoice.dart';
import 'listener.dart';

export 'listener.dart';

/// The context. It is named after the business operation rather than
/// `Context`, which reads badly next to Flutter's `BuildContext`.
class InvoiceAccount {
  final BillableAccount _account;
  final List<Charge> _charges;
  final DateTime _on;
  final InvoiceAccountListener _listener;

  static Future<InvoiceRecord?> call({
    required Account account,
    required List<Charge> charges,
    required Notifier notifier,
    DateTime? on,
    InvoiceAccountListener listener = const NullInvoiceAccountListener(),
  }) =>
      InvoiceAccount._(
        account: _castAccount(account, notifier),
        charges: charges,
        on: on ?? DateTime.now(),
        listener: listener,
      )._run();

  InvoiceAccount._({
    required BillableAccount account,
    required List<Charge> charges,
    required DateTime on,
    required InvoiceAccountListener listener,
  })  : _account = account,
        _charges = charges,
        _on = on,
        _listener = listener;

  // To invoice an account:
  //   1. if the account has no uninvoiced charges, there is nothing to do
  //   2. build a draft invoice from the charges
  //   3. if its total is far out of line with past invoices, hold it for review
  //   4. otherwise finalize it and notify the account
  Future<InvoiceRecord?> _run() async {
    // An account with nothing new to bill gets no invoice at all, not an empty
    // one. (Business rule R1.)
    if (_charges.isEmpty) {
      _listener.nothingToInvoice(_account.unwrap());
      return null;
    }

    final invoice = DraftInvoice.newFor(_account.id);
    BuildInvoice.call(invoice: invoice, account: _account, charges: _charges, on: _on);

    if (invoice.inBounds(_account.pastInvoiceTotalsCents)) {
      await invoice.finalize();
      await _account.notifyOfInvoice(invoice);
      _listener.invoiceFinalized(invoice.unwrap());
    } else {
      // A held invoice waits for a person to review it, so nobody is told
      // about it yet. (Business rule R5.)
      await invoice.hold();
      _listener.invoiceHeld(invoice.unwrap());
    }

    return invoice.unwrap(); // control our return value
  }

  static BillableAccount _castAccount(Account account, Notifier notifier) =>
      account.billedThroughReseller ? ResellerBilledAccount(account) : DirectBilledAccount(account, notifier: notifier);
}
