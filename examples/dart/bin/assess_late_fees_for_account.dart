// Entry point (driving adapter): Ops runs late fees for one account when a
// customer calls in. Same context and rules as the nightly job; narrower scope
// and a listener that narrates every step.
//
//   dart run bin/assess_late_fees_for_account.dart ACCOUNT_ID
import 'dart:io';

import 'package:hexadci_example/features/assess_late_fees/assess_late_fees.dart';

import 'demo_data.dart';

Future<void> main(List<String> args) async {
  final id = args.isEmpty ? null : int.tryParse(args.first);
  final matches = accounts.where((a) => a.id == id);
  if (matches.isEmpty) {
    stderr.writeln('No account ${args.isEmpty ? '' : args.first}');
    exitCode = 1;
    return;
  }
  final account = matches.single;

  final run = await AssessLateFees.call(
      invoices: openInvoices().where((i) => i.accountId == account.id).toList(),
      accounts: [account],
      bank: DemoBank(),
      notice: StdoutLateFeeNotice(),
      on: today,
      listener: PrintingListener());

  exitCode = run.bankUnavailable != null ? 2 : 0;
}
