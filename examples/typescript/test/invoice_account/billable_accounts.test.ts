import { test } from "node:test";
import assert from "node:assert/strict";
import {
  DirectBilledAccount,
  ResellerBilledAccount,
} from "../../src/features/invoice_account/billable_accounts.ts";
import { DraftInvoice } from "../../src/features/invoice_account/draft_invoice.ts";
import { InvoiceRecord } from "../../src/records/index.ts";
import type { Account } from "../../src/records/index.ts";
import { FakeNotifier, account, contact } from "../fakes.ts";

function recipientsFor(acct: Account) {
  return new ResellerBilledAccount(acct).recipients();
}

test("recipients are the billing contacts when present", () => {
  const billing = [contact("Pat")];
  const acct = account({ billingContacts: billing, companyEmail: "co@example.test", contacts: [contact("Sam")] });
  assert.deepEqual(recipientsFor(acct), billing);
});

test("recipients fall back to the company email", () => {
  const acct = account({ companyEmail: "co@example.test", contacts: [contact("Sam")] });
  assert.deepEqual(recipientsFor(acct).map((r) => r.email), ["co@example.test"]);
});

test("recipients fall back to all contacts", () => {
  const everyone = [contact("Sam"), contact("Lee")];
  assert.deepEqual(recipientsFor(account({ contacts: everyone })), everyone);
});

test("a direct-billed account notifies its recipients", () => {
  const notifier = new FakeNotifier();
  const role = new DirectBilledAccount(account({ companyEmail: "co@example.test" }), notifier);
  const invoice = new DraftInvoice(new InvoiceRecord(7));

  role.notifyOfInvoice(invoice);

  assert.equal(notifier.sent.length, 1);
  assert.deepEqual(notifier.sent[0].recipients.map((r) => r.email), ["co@example.test"]);
  assert.equal(notifier.sent[0].invoice, invoice.unwrap());
});

test("a reseller-billed account is never notified", () => {
  const role = new ResellerBilledAccount(account({ companyEmail: "co@example.test" }));
  assert.equal(role.notifyOfInvoice(), undefined);
});
