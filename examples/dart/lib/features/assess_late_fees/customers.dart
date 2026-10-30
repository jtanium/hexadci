import '../../records/records.dart';
import 'late_fee_notice.dart';

/// The account, in the role of "the customer whose invoice is overdue".
sealed class Customer {
  final Account _account;
  final LateFeeNotice _notice;

  Customer(this._account, this._notice);

  int get id => _account.id;

  bool get onPaymentPlan => _account.onPaymentPlan;

  String get bankAccountNumber => _account.bankAccountNumber ?? '';

  Future<void> notifyOfLateFee(InvoiceRecord invoice, int feeCents);

  Account unwrap() => _account;
}

final class DirectCustomer extends Customer {
  DirectCustomer(super.account, super.notice);

  @override
  Future<void> notifyOfLateFee(InvoiceRecord invoice, int feeCents) =>
      _notice.lateFeeAdded(to: _account.companyEmail ?? '', invoice: invoice, feeCents: feeCents);
}

final class ResellerCustomer extends Customer {
  ResellerCustomer(super.account, super.notice);

  /// A customer who came through a reseller is the reseller's to manage: we
  /// tell the reseller about the fee and never contact the customer directly.
  /// Everyone else hears from us at their billing address. (Business rule R6.)
  @override
  Future<void> notifyOfLateFee(InvoiceRecord invoice, int feeCents) =>
      _notice.lateFeeAdded(to: _account.resellerEmail ?? '', invoice: invoice, feeCents: feeCents);
}
