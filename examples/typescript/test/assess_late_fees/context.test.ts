import { beforeEach, test } from "node:test";
import assert from "node:assert/strict";
import * as AssessLateFees from "../../src/features/assess_late_fees/index.ts";
import type { Account, InvoiceRecord } from "../../src/records/index.ts";
import { FakeBank, FakeNotice, RecordingListener, TODAY, account, deposit, invoice } from "./fakes.ts";

let bank: FakeBank;
let notice: FakeNotice;
let listener: RecordingListener;

beforeEach(() => {
  bank = new FakeBank();
  notice = new FakeNotice();
  listener = new RecordingListener();
});

function assess(invoices: InvoiceRecord[], accounts: Account[] = [account()]) {
  return AssessLateFees.Context.call({ invoices, accounts, bank, notice, on: TODAY, listener });
}

// [description, invoice attributes, account attributes, charged?]
const WHO_IS_CHARGED: [string, Parameters<typeof invoice>[0], Partial<Account>, boolean][] = [
  ["more than 30 days past due", { daysPastDue: 31 }, {}, true],
  ["exactly 30 days past due", { daysPastDue: 30 }, {}, false],
  ["last fee only 10 days ago", { daysPastDue: 90, lastFeeDaysAgo: 10 }, {}, false],
  ["last fee 30 days ago", { daysPastDue: 90, lastFeeDaysAgo: 30 }, {}, true],
  ["customer on a payment plan", { daysPastDue: 90 }, { onPaymentPlan: true }, false],
];

for (const [description, invoiceAttrs, accountAttrs, charged] of WHO_IS_CHARGED) {
  test(`who is charged: ${description}`, () => {
    const run = assess([invoice(invoiceAttrs)], [account(accountAttrs)]);
    assert.equal(run.lateFees.length, charged ? 1 : 0);
  });
}

// [description, deposits at the bank, found paid?]
const BANK_CASES: [string, Parameters<typeof deposit>[0][], boolean][] = [
  ["cleared deposit covering the balance", [{ amt: "1000.00" }], true],
  ["cleared deposit over the balance", [{ amt: "1500.00" }], true],
  ["cleared deposit short of the balance", [{ amt: "999.99" }], false],
  ["pending deposit covering the balance", [{ sts: "PND" }], false],
  ["deposit for another invoice", [{ memo: "INV 2026-0999" }], false],
  ["memo with a longer number containing ours", [{ memo: "INV 2026-04120" }], false],
];

for (const [description, deposits, paid] of BANK_CASES) {
  test(`bank check before charging: ${description}`, () => {
    bank = new FakeBank({ "acct-1": deposits.map((attrs) => deposit(attrs)) });
    const record = invoice();
    const run = assess([record]);

    assert.deepEqual(run.foundPaid, paid ? ["2026-0412"] : []);
    assert.equal(record.status, paid ? "paid" : "open");
    assert.equal(run.lateFees.length, paid ? 0 : 1);
  });
}

test("a late fee is added and the billing contact told", () => {
  const record = invoice({ balanceCents: 100_000 });
  const run = assess([record]);

  assert.deepEqual(run.lateFees, [["2026-0412", 1_500]]);
  assert.equal(record.balanceCents, 101_500);
  assert.deepEqual(notice.sent, [{ to: "ap1@example.test", number: "2026-0412", feeCents: 1_500 }]);
});

test("the reseller is told instead of the customer", () => {
  assess([invoice()], [account({ billedThroughReseller: true, resellerEmail: "billing@reseller.test" })]);
  assert.deepEqual(notice.sent.map((n) => n.to), ["billing@reseller.test"]);
});

test("bank down means nobody is charged or marked paid", () => {
  bank = new FakeBank({}, { down: true });
  const records = [invoice({ number: "A-1" }), invoice({ number: "B-2", accountId: 2 })];

  const run = assess(records, [account({ id: 1 }), account({ id: 2 })]);

  assert.equal(run.bankUnavailable, "bank is down");
  assert.deepEqual(run.lateFees, []);
  assert.ok(records.every((r) => r.status === "open" && r.lateFees.length === 0));
  assert.deepEqual(notice.sent, []);
  assert.deepEqual(listener.names(), ["bankUnavailable", "runFinished"]);
});

test("payment-plan customers are never checked at the bank", () => {
  bank = new FakeBank({}, { down: true });
  const run = assess([invoice({ daysPastDue: 90 })], [account({ onPaymentPlan: true })]);

  assert.deepEqual(bank.askedAbout, []);
  assert.equal(run.bankUnavailable, null);
});

test("an unreadable deposit stops that customer only", () => {
  bank = new FakeBank({ "acct-1": [deposit({ amt: "twelve" })], "acct-2": [] });
  const run = assess(
    [invoice({ number: "A-1" }), invoice({ number: "B-2", accountId: 2 })],
    [account({ id: 1 }), account({ id: 2 })],
  );

  assert.deepEqual(run.notProcessed.map(([n]) => n), ["A-1"]);
  assert.match(run.notProcessed[0][1], /could not read deposit/);
  assert.deepEqual(run.lateFees.map(([n]) => n), ["B-2"]);
});

test("a failed notice is a warning and the fee stands", () => {
  notice = new FakeNotice({ failing: true });
  const record = invoice();
  const run = assess([record]);

  assert.equal(record.lateFees.length, 1);
  assert.deepEqual(run.warnings.map(([n]) => n), ["2026-0412"]);
  assert.ok(listener.names().includes("lateFeeNoticeFailed"));
});

test("an invoice without an account is reported and the rest continue", () => {
  const run = assess([invoice({ number: "ORPHAN", accountId: 99 }), invoice({ number: "A-1" })]);

  assert.deepEqual(run.notProcessed, [["ORPHAN", "no account 99"]]);
  assert.deepEqual(run.lateFees.map(([n]) => n), ["A-1"]);
});

test("one deposit pays one invoice", () => {
  bank = new FakeBank({ "acct-1": [deposit({ memo: "2026-0412 2026-0413" })] });
  const run = assess([invoice({ number: "2026-0412" }), invoice({ number: "2026-0413" })]);

  assert.deepEqual(run.foundPaid, ["2026-0412"]);
  assert.deepEqual(run.lateFees.map(([n]) => n), ["2026-0413"]);
});

test("an invoice listed twice is charged and notified once", () => {
  const record = invoice({ balanceCents: 100_000 });

  const run = assess([record, record]);

  assert.deepEqual(run.lateFees, [["2026-0412", 1_500]]);
  assert.equal(record.balanceCents, 101_500);
  assert.equal(notice.sent.length, 1);
  assert.deepEqual(run.notProcessed, [["2026-0412", "listed more than once in this run"]]);
});

test("one transaction pays one invoice even when customers share a bank account", () => {
  const shared = "shared-acct";
  bank = new FakeBank({ [shared]: [deposit({ memo: "2026-0412 2026-0413", txn_id: "T-77" })] });
  const records = [invoice({ number: "2026-0412", accountId: 1 }), invoice({ number: "2026-0413", accountId: 2 })];

  const run = assess(records, [
    account({ id: 1, bankAccountNumber: shared }),
    account({ id: 2, bankAccountNumber: shared }),
  ]);

  assert.deepEqual(run.foundPaid, ["2026-0412"]);
  assert.deepEqual(run.lateFees.map(([n]) => n), ["2026-0413"]);
});

test("a failed notice is sent on the next run", () => {
  const record = invoice();
  notice = new FakeNotice({ failing: true });
  const first = assess([record]);
  assert.deepEqual(first.warnings.map(([n]) => n), ["2026-0412"]);
  assert.equal(record.lateFees[0].noticeSent, false);

  notice.failing = false;
  listener = new RecordingListener();
  const second = assess([record]);

  assert.deepEqual(second.lateFees, []); // not charged again: the last fee was today
  assert.deepEqual(second.earlierNoticesSent, ["2026-0412"]);
  assert.deepEqual(notice.sent, [{ to: "ap1@example.test", number: "2026-0412", feeCents: 1_500 }]);
  assert.equal(record.lateFees[0].noticeSent, true);
  assert.ok(listener.names().includes("earlierNoticeSent"));
});

test("a notice that keeps failing is reported again each run", () => {
  const record = invoice();
  notice = new FakeNotice({ failing: true });
  assess([record]);

  const second = assess([record]);

  assert.deepEqual(second.warnings.map(([n]) => n), ["2026-0412"]);
  assert.equal(record.lateFees[0].noticeSent, false);
});

test("earlier notices go out even when the bank is down", () => {
  const record = invoice();
  record.lateFees.push({ amountCents: 1_500, assessedOn: TODAY }); // notice never sent
  bank = new FakeBank({}, { down: true });

  const run = assess([record]);

  assert.deepEqual(run.earlierNoticesSent, ["2026-0412"]);
  assert.deepEqual(run.lateFees, []);
});

test("programming errors are not hidden as record problems", () => {
  const broken = invoice();
  broken.dueDate = undefined; // a bug upstream, not bad customer data

  assert.throws(
    () => assess([broken]),
    (error: unknown) => error instanceof Error && !(error instanceof AssessLateFees.RecordProblem),
  );
});

test("returns the run and reports it", () => {
  const run = assess([invoice()]);

  assert.ok(run instanceof AssessLateFees.Run);
  assert.deepEqual(listener.events.at(-1), ["runFinished", run]);
});
