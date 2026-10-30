// Entry point (driving adapter): a CLI.
//
// It gathers inputs, calls the context, and lets the listener decide what the
// outcome means here. A web handler would implement the Listener interface
// itself and respond in its methods instead.
import * as InvoiceAccount from "../features/invoice_account/index.ts";
import { StdoutNotifier } from "../ports/notifier.ts";
import type { Account, Charge } from "../records/index.ts";

const account: Account = {
  id: 42,
  name: "Example Coffee",
  companyEmail: "billing@example.test",
  billingContacts: [],
  contacts: [],
  billedThroughReseller: false,
  pastInvoiceTotalsCents: [10_000, 10_500, 9_800],
};
const charges: Charge[] = [
  { description: "Monthly gateway fee", amountCents: 2_995 },
  { description: "Processing fees", amountCents: 7_310 },
];

InvoiceAccount.Context.call({
  account,
  charges,
  notifier: new StdoutNotifier(),
  listener: new InvoiceAccount.PrintingListener(),
});
