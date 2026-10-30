import { beforeEach, test } from "node:test";
import assert from "node:assert/strict";
import * as InvoiceAccount from "../../src/features/invoice_account/index.ts";
import { InvoiceRecord } from "../../src/records/index.ts";
import type { Account, Charge } from "../../src/records/index.ts";
import { FakeNotifier, RecordingListener, account, charge } from "../fakes.ts";

const STEADY_HISTORY = [10_000, 10_000, 10_000];

let listener: RecordingListener;
let notifier: FakeNotifier;

beforeEach(() => {
  listener = new RecordingListener();
  notifier = new FakeNotifier();
});

function invoice(acct: Account, charges: Charge[]) {
  return InvoiceAccount.Context.call({ account: acct, charges, notifier, on: new Date(2026, 9, 1), listener });
}

test("nothing to invoice without charges", () => {
  const acct = account();

  assert.equal(invoice(acct, []), null);
  assert.deepEqual(listener.events, [["nothingToInvoice", acct]]);
  assert.equal(notifier.sent.length, 0);
});

test("an in-bounds invoice is finalized and the account notified", () => {
  const result = invoice(account({ companyEmail: "co@example.test", pastInvoiceTotalsCents: STEADY_HISTORY }), [charge(10_200)]);

  assert.equal(result?.status, "final");
  assert.deepEqual(listener.events, [["invoiceFinalized", result]]);
  assert.equal(notifier.sent.length, 1);
});

test("a reseller-billed account is finalized but not notified", () => {
  const result = invoice(account({ billedThroughReseller: true, pastInvoiceTotalsCents: STEADY_HISTORY }), [charge(10_200)]);

  assert.equal(result?.status, "final");
  assert.deepEqual(listener.events, [["invoiceFinalized", result]]);
  assert.equal(notifier.sent.length, 0);
});

test("an out-of-bounds invoice is held and nobody is notified", () => {
  const result = invoice(account({ companyEmail: "co@example.test", pastInvoiceTotalsCents: STEADY_HISTORY }), [charge(25_000)]);

  assert.equal(result?.status, "held");
  assert.deepEqual(listener.events, [["invoiceHeld", result]]);
  assert.equal(notifier.sent.length, 0);
});

test("returns the invoice record", () => {
  const result = invoice(account({ companyEmail: "co@example.test" }), [charge(1_000)]);
  assert.ok(result instanceof InvoiceRecord);
});

test("works with the default null listener", () => {
  const result = InvoiceAccount.Context.call({
    account: account({ companyEmail: "co@example.test" }),
    charges: [charge(1_000)],
    notifier,
  });
  assert.equal(result?.status, "final");
});
