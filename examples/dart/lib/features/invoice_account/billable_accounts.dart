import '../../ports/notifier.dart';
import '../../records/records.dart';
import 'draft_invoice.dart';

/// The account, in the role of "the one being invoiced".
///
/// `sealed`: these are all the kinds of billable account there are; the
/// compiler knows it, and so does the reader.
sealed class BillableAccount {
  final Account _account;

  BillableAccount(this._account);

  int get id => _account.id;

  List<int> get pastInvoiceTotalsCents => _account.pastInvoiceTotalsCents;

  /// Invoices go to the people the account asked us to bill. If it named no
  /// billing contacts, they go to the company's own email address; if there is
  /// none, to everyone we have on file, so the invoice always reaches someone.
  /// (Business rule R3.)
  List<Contact> get recipients => _billingContacts._ifAny ?? _companyAddress._ifAny ?? _account.contacts;

  List<Contact> get _billingContacts => _account.billingContacts;

  List<Contact> get _companyAddress => switch (_account.companyEmail) {
        final email? => [Contact(name: _account.name, email: email)],
        null => [],
      };

  Future<void> notifyOfInvoice(DraftInvoice invoice);

  Account unwrap() => _account;
}

final class DirectBilledAccount extends BillableAccount {
  final Notifier _notifier;

  DirectBilledAccount(super.account, {required Notifier notifier}) : _notifier = notifier;

  @override
  Future<void> notifyOfInvoice(DraftInvoice invoice) =>
      _notifier.invoiceReady(recipients: recipients, invoice: invoice.unwrap());
}

final class ResellerBilledAccount extends BillableAccount {
  ResellerBilledAccount(super.account);

  /// The reseller sends this account its invoices and owns the relationship,
  /// so we never contact the account directly. (Business rule R6.)
  @override
  Future<void> notifyOfInvoice(DraftInvoice invoice) async {}
}

extension on List<Contact> {
  /// These contacts, or null if there are none, so alternatives chain with `??`.
  List<Contact>? get _ifAny => isEmpty ? null : this;
}
