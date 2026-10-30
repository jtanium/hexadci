import { test } from "node:test";
import assert from "node:assert/strict";
import { ImpossibleRun, Run, UnrecognizedDeposit } from "../../src/features/assess_late_fees/index.ts";
import { DirectCustomer } from "../../src/features/assess_late_fees/customers.ts";
import { ChargeableInvoice, PaymentPlanInvoice } from "../../src/features/assess_late_fees/late_fee_invoices.ts";
import { NullLateFeeNotice } from "../../src/features/assess_late_fees/late_fee_notice.ts";
import { RetrieveDeposits } from "../../src/features/assess_late_fees/retrieve_deposits.ts";
import type { RawDeposit } from "../../src/ports/bank.ts";
import { FakeBank, account, deposit, invoice } from "./fakes.ts";

const customer = new DirectCustomer(account(), new NullLateFeeNotice());

// [description, balance cents, fee cents]
const FEE_RULES: [string, number, number][] = [
  ["1.5% of the balance", 100_000, 1_500],
  ["never less than $5.00", 20_000, 500],
  ["half a cent rounds up", 50_100, 752],
  ["under half a cent rounds down", 50_033, 750],
];

for (const [description, balance, fee] of FEE_RULES) {
  test(`late fee: ${description}`, () => {
    assert.equal(new ChargeableInvoice(invoice({ balanceCents: balance }), customer).lateFeeCents, fee);
  });
}

test("payment-plan invoices are never due", () => {
  assert.equal(new PaymentPlanInvoice(invoice({ daysPastDue: 365 }), customer).dueForLateFee(), false);
});

function deposits(...raw: RawDeposit[]) {
  return RetrieveDeposits.call({ bank: new FakeBank({ "acct-1": raw }), bankAccountNumber: "acct-1" });
}

test("translates the bank's fields into ours", () => {
  const [translated] = deposits(deposit({ amt: "125.5", memo: "INV 7", sts: "PND" }));

  assert.equal(translated.amountCents, 12_550);
  assert.equal(translated.memo, "INV 7");
  assert.equal(translated.cleared, false);
});

test("whole-dollar amounts", () => {
  assert.equal(deposits(deposit({ amt: "125" }))[0].amountCents, 12_500);
});

test("keeps the bank's transaction id", () => {
  assert.equal(deposits(deposit({ txn_id: "T-42" }))[0].transactionId, "T-42");
});

test("refuses what it cannot read", () => {
  const unreadable = [deposit({ amt: "12.345" }), deposit({ amt: "-5.00" }), deposit({ sts: "XYZ" }), deposit({ txn_id: "" })];
  for (const raw of unreadable) {
    assert.throws(() => deposits(raw), UnrecognizedDeposit);
  }
});

test("impossible runs throw", () => {
  const changedWhileDown = new Run();
  changedWhileDown.bankUnavailable = "down";
  changedWhileDown.lateFees.push(["A-1", 1_500]);

  const belowMinimum = new Run();
  belowMinimum.lateFees.push(["A-1", 100]);

  const changedTwice = new Run();
  changedTwice.lateFees.push(["A-1", 1_500]);
  changedTwice.foundPaid.push("A-1");

  for (const run of [changedWhileDown, belowMinimum, changedTwice]) {
    assert.throws(() => run.checkTotals(), ImpossibleRun);
  }
});

test("a reported repeat is not an impossible run", () => {
  const run = new Run();
  run.lateFees.push(["A-1", 1_500]);
  run.notProcessed.push(["A-1", "listed more than once in this run"]);

  assert.doesNotThrow(() => run.checkTotals());
});
