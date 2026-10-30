import { test } from "node:test";
import assert from "node:assert/strict";
import { DirectBilledAccount } from "../../src/features/invoice_account/billable_accounts.ts";
import { BuildInvoice } from "../../src/features/invoice_account/build_invoice.ts";
import { DraftInvoice } from "../../src/features/invoice_account/draft_invoice.ts";
import { FakeNotifier, account, charge } from "../fakes.ts";

test("dates, addresses, and adds a line per charge", () => {
  const acct = new DirectBilledAccount(account({ companyEmail: "co@example.test" }), new FakeNotifier());
  const invoice = DraftInvoice.newFor(acct);
  const on = new Date(2026, 9, 1);

  BuildInvoice.call({ invoice, account: acct, on, charges: [charge(2_995, "Monthly fee"), charge(7_310, "Processing")] });

  const record = invoice.unwrap();
  assert.equal(record.invoiceDate, on);
  assert.deepEqual(record.recipients.map((r) => r.email), ["co@example.test"]);
  assert.deepEqual(record.lines.map((l) => l.description), ["Monthly fee", "Processing"]);
  assert.equal(record.totalCents, 10_305);
});
