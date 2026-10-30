// Port: tells people that something is ready for them.
//
// Implementations decide how (email, push notification, a queue). Business
// operations only know the message they send.
import 'dart:io';

import '../records/records.dart';

abstract interface class Notifier {
  Future<void> invoiceReady({required List<Contact> recipients, required InvoiceRecord invoice});
}

class StdoutNotifier implements Notifier {
  final StringSink out;

  StdoutNotifier([StringSink? out]) : out = out ?? stdout;

  @override
  Future<void> invoiceReady({required List<Contact> recipients, required InvoiceRecord invoice}) async {
    out.writeln('Notified ${recipients.map((r) => r.email).join(', ')} of invoice for account ${invoice.accountId}');
  }
}

class NullNotifier implements Notifier {
  @override
  Future<void> invoiceReady({required List<Contact> recipients, required InvoiceRecord invoice}) async {
    // no-op
  }
}
