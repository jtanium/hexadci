// Port: tells someone a late fee was added. Only this feature uses it, so it
// lives in the feature folder. Implementations throw NoticeFailed when they
// cannot deliver.
//
// Telling the customer is a business requirement (R6), so the context has no
// default notice: production must pass a real one. NullLateFeeNotice exists for
// previews and tests that say explicitly they do not want notices.
import 'dart:io';

import '../../records/records.dart';

abstract interface class LateFeeNotice {
  Future<void> lateFeeAdded({required String to, required InvoiceRecord invoice, required int feeCents});
}

class StdoutLateFeeNotice implements LateFeeNotice {
  final StringSink out;

  StdoutLateFeeNotice([StringSink? out]) : out = out ?? stdout;

  @override
  Future<void> lateFeeAdded({required String to, required InvoiceRecord invoice, required int feeCents}) async {
    out.writeln('Told $to about a \$${(feeCents / 100).toStringAsFixed(2)} late fee on ${invoice.number}');
  }
}

class NullLateFeeNotice implements LateFeeNotice {
  const NullLateFeeNotice();

  @override
  Future<void> lateFeeAdded({required String to, required InvoiceRecord invoice, required int feeCents}) async {}
}
