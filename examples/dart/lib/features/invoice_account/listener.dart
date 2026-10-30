import 'dart:io';

import '../../records/records.dart';

/// The outcomes of invoicing an account. In a Flutter app, the Cubit or
/// notifier that drives the screen usually implements this itself.
abstract interface class InvoiceAccountListener {
  void nothingToInvoice(Account account);
  void invoiceFinalized(InvoiceRecord invoice);
  void invoiceHeld(InvoiceRecord invoice);
}

class NullInvoiceAccountListener implements InvoiceAccountListener {
  const NullInvoiceAccountListener();

  @override
  void nothingToInvoice(Account account) {}

  @override
  void invoiceFinalized(InvoiceRecord invoice) {}

  @override
  void invoiceHeld(InvoiceRecord invoice) {}
}

/// Turns on output for this feature only, e.g. from a CLI or while debugging.
class PrintingInvoiceAccountListener implements InvoiceAccountListener {
  final StringSink out;

  PrintingInvoiceAccountListener([StringSink? out]) : out = out ?? stdout;

  @override
  void nothingToInvoice(Account account) => out.writeln('Nothing to invoice for ${account.name}');

  @override
  void invoiceFinalized(InvoiceRecord invoice) =>
      out.writeln('Finalized invoice for account ${invoice.accountId}: ${_dollars(invoice.totalCents)}');

  @override
  void invoiceHeld(InvoiceRecord invoice) =>
      out.writeln('Held invoice for account ${invoice.accountId} for review: ${_dollars(invoice.totalCents)}');
}

String _dollars(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';
