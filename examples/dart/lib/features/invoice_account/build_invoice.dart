import '../../records/records.dart';
import 'billable_accounts.dart';
import 'draft_invoice.dart';

/// An invoice is dated the day it is built, addressed to the account's billing
/// recipients, and lists every uninvoiced charge on its own line, so the total is
/// exactly what the account owes for the period. (Business rule R2.)
class BuildInvoice {
  final DraftInvoice _invoice;
  final BillableAccount _account;
  final List<Charge> _charges;
  final DateTime _on;

  static DraftInvoice call({
    required DraftInvoice invoice,
    required BillableAccount account,
    required List<Charge> charges,
    required DateTime on,
  }) =>
      BuildInvoice._(invoice, account, charges, on)._build();

  BuildInvoice._(this._invoice, this._account, this._charges, this._on);

  DraftInvoice _build() {
    _invoice.date(_on);
    _invoice.addressTo(_account.recipients);
    for (final charge in _charges) {
      _invoice.addLine(description: charge.description, amountCents: charge.amountCents);
    }
    return _invoice;
  }
}
