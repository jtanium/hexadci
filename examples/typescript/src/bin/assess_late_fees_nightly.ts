// Entry point (driving adapter): the nightly job.
//
// Scope: every open invoice. In a real app these would come from the database.
// Prints only the summary.
import * as AssessLateFees from "../features/assess_late_fees/index.ts";
import { ACCOUNTS, DemoBank, TODAY, openInvoices } from "./demo_data.ts";

const run = AssessLateFees.Context.call({
  invoices: openInvoices(),
  accounts: ACCOUNTS,
  bank: new DemoBank(),
  notice: new AssessLateFees.StdoutLateFeeNotice(),
  on: TODAY,
  listener: new AssessLateFees.SummaryListener(),
});

process.exitCode = run.bankUnavailable ? 2 : 0;
