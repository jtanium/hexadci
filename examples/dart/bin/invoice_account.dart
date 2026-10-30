// Entry point (driving adapter): a CLI.
//
// It gathers inputs, calls the context, and lets the listener decide what the
// outcome means here. In a Flutter app the entry point is a Cubit or notifier
// method called from a widget; it implements InvoiceAccountListener and emits
// new UI state from its callbacks.
import 'package:hex_dci_example/features/invoice_account/invoice_account.dart';
import 'package:hex_dci_example/ports/notifier.dart';
import 'package:hex_dci_example/records/records.dart';

Future<void> main() async {
  const account = Account(
      id: 42,
      name: 'Example Coffee',
      companyEmail: 'billing@example.test',
      pastInvoiceTotalsCents: [10000, 10500, 9800]);
  const charges = [
    Charge(description: 'Monthly gateway fee', amountCents: 2995),
    Charge(description: 'Processing fees', amountCents: 7310),
  ];

  await InvoiceAccount.call(
      account: account, charges: charges, notifier: StdoutNotifier(), listener: PrintingInvoiceAccountListener());
}
