import 'dart:io';

import '../../records/records.dart';
import 'run.dart';

/// The outcomes of a late-fee run.
abstract interface class AssessLateFeesListener {
  void invoiceNotProcessed(String number, String reason);
  void lateFeeAdded(InvoiceRecord invoice, int feeCents);
  void invoiceFoundPaid(InvoiceRecord invoice);
  void lateFeeNoticeFailed(InvoiceRecord invoice, String reason);
  void earlierNoticeSent(InvoiceRecord invoice, int feeCents);
  void bankUnavailable(String reason);
  void runFinished(Run run);
}

class NullAssessLateFeesListener implements AssessLateFeesListener {
  const NullAssessLateFeesListener();

  @override
  void invoiceNotProcessed(String number, String reason) {}
  @override
  void lateFeeAdded(InvoiceRecord invoice, int feeCents) {}
  @override
  void invoiceFoundPaid(InvoiceRecord invoice) {}
  @override
  void lateFeeNoticeFailed(InvoiceRecord invoice, String reason) {}
  @override
  void earlierNoticeSent(InvoiceRecord invoice, int feeCents) {}
  @override
  void bankUnavailable(String reason) {}
  @override
  void runFinished(Run run) {}
}

/// Nightly: only the summary Ops asked for.
class SummaryListener extends NullAssessLateFeesListener {
  final StringSink out;

  SummaryListener([StringSink? out]) : out = out ?? stdout;

  @override
  void runFinished(Run run) {
    if (run.bankUnavailable != null) {
      out.writeln('BANK UNAVAILABLE (${run.bankUnavailable}): no late fees were charged tonight');
    }
    out.writeln('Late fees added: ${run.lateFees.length}, total ${_dollars(run.lateFeeTotalCents)}');
    out.writeln('Invoices found already paid: ${run.foundPaid.length}');
    if (run.earlierNoticesSent.isNotEmpty) {
      out.writeln('Notices from earlier runs sent: ${run.earlierNoticesSent.length}');
    }
    for (final (number, reason) in [...run.notProcessed, ...run.warnings]) {
      out.writeln('  $number: $reason');
    }
  }
}

/// Single customer at the command line: narrate everything.
class PrintingListener extends SummaryListener {
  PrintingListener([super.out]);

  @override
  void invoiceNotProcessed(String number, String reason) => out.writeln('Could not process $number: $reason');

  @override
  void lateFeeAdded(InvoiceRecord invoice, int feeCents) =>
      out.writeln('Added ${_dollars(feeCents)} late fee to ${invoice.number}');

  @override
  void invoiceFoundPaid(InvoiceRecord invoice) =>
      out.writeln('${invoice.number} was already paid at the bank; marked paid');

  @override
  void lateFeeNoticeFailed(InvoiceRecord invoice, String reason) =>
      out.writeln('Late fee on ${invoice.number} stands, but the notice failed: $reason');

  @override
  void earlierNoticeSent(InvoiceRecord invoice, int feeCents) =>
      out.writeln('Sent the notice for the earlier ${_dollars(feeCents)} late fee on ${invoice.number}');

  @override
  void bankUnavailable(String reason) => out.writeln('Bank unavailable ($reason); charging nobody');
}

String _dollars(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';
