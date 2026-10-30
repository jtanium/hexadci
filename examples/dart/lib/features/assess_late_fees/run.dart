import 'errors.dart';
import 'late_fee_invoices.dart';

/// The result of one run: what Ops sees in the nightly summary.
class Run {
  final List<(String invoiceNumber, int feeCents)> lateFees = [];
  final List<String> foundPaid = [];
  final List<(String invoiceNumber, String reason)> notProcessed = [];
  final List<(String invoiceNumber, String reason)> warnings = [];
  final List<String> earlierNoticesSent = []; // invoice numbers (R9)
  String? bankUnavailable;

  int get lateFeeTotalCents => lateFees.fold(0, (sum, fee) => sum + fee.$2);

  /// Impossible results (N1-N3 in RULES.md) mean something upstream is wrong; stop loudly.
  ///
  /// This is a diagnostic, not the guard: by the time it runs, changes have been
  /// made. The guards are the bank gate (R5) and duplicate rejection (R8), which
  /// act before anything changes.
  void checkTotals() {
    if (bankUnavailable != null && (lateFees.isNotEmpty || foundPaid.isNotEmpty)) {
      throw ImpossibleRun('invoices were changed although the bank was unavailable');
    }
    if (lateFees.any((fee) => fee.$2 < minimumFeeCents)) {
      throw ImpossibleRun('a late fee is below the minimum: $lateFees');
    }

    final changed = [...lateFees.map((f) => f.$1), ...foundPaid];
    final duplicates = {for (final n in changed) if (changed.where((c) => c == n).length > 1) n};
    if (duplicates.isNotEmpty) throw ImpossibleRun('invoices changed more than once: $duplicates');
  }
}
