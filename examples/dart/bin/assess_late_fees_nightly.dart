// Entry point (driving adapter): the nightly job.
//
// Scope: every open invoice. In a real app these would come from the database.
// Prints only the summary.
import 'dart:io';

import 'package:hex_dci_example/features/assess_late_fees/assess_late_fees.dart';

import 'demo_data.dart';

Future<void> main() async {
  final run = await AssessLateFees.call(
      invoices: openInvoices(),
      accounts: accounts,
      bank: DemoBank(),
      notice: StdoutLateFeeNotice(),
      on: today,
      listener: SummaryListener());

  exitCode = run.bankUnavailable != null ? 2 : 0;
}
