import { test } from "node:test";
import assert from "node:assert/strict";
import { DraftInvoice } from "../../src/features/invoice_account/draft_invoice.ts";
import { InvoiceRecord } from "../../src/records/index.ts";

function invoiceTotaling(cents: number): DraftInvoice {
  const invoice = new DraftInvoice(new InvoiceRecord(1));
  invoice.addLine({ description: "Fee", amountCents: cents });
  return invoice;
}

// [description, past totals, this total, in bounds?]
const IN_BOUNDS_RULES: [string, number[], number, boolean][] = [
  ["no history",                        [],                       1_000_000, true],
  ["fewer than three past invoices",    [1_000, 1_000],           1_000_000, true],
  ["within $5.00 of the average",       [10_000, 10_000, 10_000], 10_500,    true],
  ["just over $5.00 with no variation", [10_000, 10_000, 10_000], 10_501,    false],
  ["within three standard deviations",  [10_000, 20_000, 30_000], 40_000,    true],
  ["beyond three standard deviations",  [10_000, 20_000, 30_000], 50_000,    false],
  ["far below the average counts too",  [10_000, 10_000, 10_000], 1_000,     false],
];

for (const [description, past, total, expected] of IN_BOUNDS_RULES) {
  test(`in bounds: ${description}`, () => {
    assert.equal(invoiceTotaling(total).inBounds(past), expected);
  });
}

test("addLine accumulates the total", () => {
  const invoice = invoiceTotaling(1_000);
  invoice.addLine({ description: "Another fee", amountCents: 250 });
  assert.equal(invoice.totalCents, 1_250);
  assert.equal(invoice.unwrap().lines.length, 2);
});

test("hold marks held and saves", () => {
  const invoice = invoiceTotaling(1_000);
  invoice.hold();
  assert.equal(invoice.unwrap().status, "held");
  assert.ok(invoice.unwrap().saved);
});

test("finalize marks final and saves", () => {
  const invoice = invoiceTotaling(1_000);
  invoice.finalize();
  assert.equal(invoice.unwrap().status, "final");
  assert.ok(invoice.unwrap().saved);
});
