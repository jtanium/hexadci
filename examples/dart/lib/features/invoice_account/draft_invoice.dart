import 'dart:math';

import '../../records/records.dart';

// Differences this small are never worth a human review.
const smallDifferenceCents = 500;
// Fewer past invoices than this is too little history to judge an invoice by.
const invoicesNeededForAHistory = 3;

/// The invoice record, in the role of "the invoice being prepared".
///
/// An extension type is a zero-cost wrapper: at runtime this *is* the record,
/// but in code it only exposes what invoicing needs. It suits roles that hold
/// nothing but the data object.
extension type DraftInvoice._(InvoiceRecord _record) {
  DraftInvoice(InvoiceRecord record) : this._(record);

  factory DraftInvoice.newFor(int accountId) => DraftInvoice(InvoiceRecord(accountId));

  void date(DateTime on) => _record.invoiceDate = on;

  void addressTo(List<Contact> recipients) => _record.recipients = [...recipients];

  void addLine({required String description, required int amountCents}) {
    _record.lines.add(InvoiceLine(description: description, amountCents: amountCents));
    _record.totalCents += amountCents;
  }

  int get totalCents => _record.totalCents;

  /// An invoice goes out without review unless it is far out of line with what
  /// this account usually pays. A new account has too little history to judge,
  /// so its invoices always go out. Otherwise an invoice is in line when it is
  /// within $5.00 of the account's average, or within the normal spread of its
  /// past invoices (three standard deviations). (Business rule R4.)
  bool inBounds(List<int> pastTotalsCents) =>
      _tooLittleHistory(pastTotalsCents) || _closeToAverage(pastTotalsCents) || _withinNormalSpread(pastTotalsCents);

  bool _closeToAverage(List<int> pastTotalsCents) =>
      (totalCents - _mean(pastTotalsCents)).abs() <= smallDifferenceCents;

  bool _withinNormalSpread(List<int> pastTotalsCents) =>
      (totalCents - _mean(pastTotalsCents)).abs() <= 3 * _standardDeviation(pastTotalsCents);

  Future<void> hold() {
    _record.status = InvoiceStatus.held;
    return _record.save();
  }

  Future<void> finalize() {
    _record.status = InvoiceStatus.finalized;
    return _record.save();
  }

  InvoiceRecord unwrap() => _record;
}

// How "history" and "spread" are measured: arithmetic, not policy.

bool _tooLittleHistory(List<int> pastTotalsCents) => pastTotalsCents.length < invoicesNeededForAHistory;

double _mean(List<int> values) => values.reduce((a, b) => a + b) / values.length;

double _standardDeviation(List<int> values) {
  // DECISION D1: the spread of all past invoices (population standard
  // deviation), not a sample estimate. See RULES.md.
  final mean = _mean(values);
  return sqrt(values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length);
}
