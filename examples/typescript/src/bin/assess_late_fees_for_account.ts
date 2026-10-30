// Entry point (driving adapter): Ops runs late fees for one account when a
// customer calls in. Same context and rules as the nightly job; narrower scope
// and a listener that narrates every step.
//
//   node --experimental-strip-types src/bin/assess_late_fees_for_account.ts ACCOUNT_ID
import * as AssessLateFees from "../features/assess_late_fees/index.ts";
import { ACCOUNTS, DemoBank, TODAY, openInvoices } from "./demo_data.ts";

const account = ACCOUNTS.find((a) => a.id === Number(process.argv[2]));
if (!account) {
  console.error(`No account ${JSON.stringify(process.argv[2])}`);
  process.exit(1);
}

const run = AssessLateFees.Context.call({
  invoices: openInvoices().filter((invoice) => invoice.accountId === account.id),
  accounts: [account],
  bank: new DemoBank(),
  notice: new AssessLateFees.StdoutLateFeeNotice(),
  on: TODAY,
  listener: new AssessLateFees.PrintingListener(),
});

process.exitCode = run.bankUnavailable ? 2 : 0;
