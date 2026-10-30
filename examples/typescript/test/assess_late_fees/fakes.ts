import { NoticeFailed, NullListener } from "../../src/features/assess_late_fees/index.ts";
import type { LateFeeNotice, Run } from "../../src/features/assess_late_fees/index.ts";
import { BankUnavailable } from "../../src/ports/bank.ts";
import type { Bank, RawDeposit } from "../../src/ports/bank.ts";
import { InvoiceRecord } from "../../src/records/index.ts";
import type { Account } from "../../src/records/index.ts";

export const TODAY = new Date(Date.UTC(2026, 9, 29));

export function daysAgo(days: number): Date {
  return new Date(TODAY.getTime() - days * 24 * 60 * 60 * 1000);
}

/**
 * Answers with the bank's own record format. Never a null object: tests say
 * exactly what the bank returns, or that it is down.
 */
export class FakeBank implements Bank {
  askedAbout: string[] = [];
  private readonly deposits: Record<string, RawDeposit[]>;
  private readonly down: boolean;

  constructor(deposits: Record<string, RawDeposit[]> = {}, { down = false } = {}) {
    this.deposits = deposits;
    this.down = down;
  }

  recentDeposits(bankAccountNumber: string): RawDeposit[] {
    this.askedAbout.push(bankAccountNumber);
    if (this.down) throw new BankUnavailable("bank is down");
    return this.deposits[bankAccountNumber] ?? [];
  }
}

export class FakeNotice implements LateFeeNotice {
  sent: { to: string; number: string | undefined; feeCents: number }[] = [];
  failing: boolean;

  constructor({ failing = false } = {}) {
    this.failing = failing;
  }

  lateFeeAdded({ to, invoice, feeCents }: { to: string; invoice: InvoiceRecord; feeCents: number }): void {
    if (this.failing) throw new NoticeFailed("mail server refused");
    this.sent.push({ to, number: invoice.number, feeCents });
  }
}

export class RecordingListener extends NullListener {
  events: unknown[][] = [];

  override invoiceNotProcessed(number: string, reason: string): void {
    this.events.push(["invoiceNotProcessed", number, reason]);
  }
  override lateFeeAdded(invoice: InvoiceRecord, feeCents: number): void {
    this.events.push(["lateFeeAdded", invoice, feeCents]);
  }
  override invoiceFoundPaid(invoice: InvoiceRecord): void {
    this.events.push(["invoiceFoundPaid", invoice]);
  }
  override lateFeeNoticeFailed(invoice: InvoiceRecord, reason: string): void {
    this.events.push(["lateFeeNoticeFailed", invoice, reason]);
  }
  override earlierNoticeSent(invoice: InvoiceRecord, feeCents: number): void {
    this.events.push(["earlierNoticeSent", invoice, feeCents]);
  }
  override bankUnavailable(reason: string): void {
    this.events.push(["bankUnavailable", reason]);
  }
  override runFinished(run: Run): void {
    this.events.push(["runFinished", run]);
  }

  names(): unknown[] {
    return this.events.map((event) => event[0]);
  }
}

export function account(overrides: Partial<Account> = {}): Account {
  const id = overrides.id ?? 1;
  return {
    id,
    name: `Account ${id}`,
    companyEmail: `ap${id}@example.test`,
    bankAccountNumber: `acct-${id}`,
    billingContacts: [],
    contacts: [],
    billedThroughReseller: false,
    pastInvoiceTotalsCents: [],
    ...overrides,
  };
}

export function invoice({
  number = "2026-0412",
  accountId = 1,
  daysPastDue = 45,
  balanceCents = 100_000,
  lastFeeDaysAgo,
}: { number?: string; accountId?: number; daysPastDue?: number; balanceCents?: number; lastFeeDaysAgo?: number } = {}) {
  const record = new InvoiceRecord(accountId, { number, dueDate: daysAgo(daysPastDue), balanceCents, status: "open" });
  if (lastFeeDaysAgo !== undefined) {
    record.lateFees.push({ amountCents: 500, assessedOn: daysAgo(lastFeeDaysAgo), noticeSent: true });
  }
  return record;
}

export function deposit({ amt = "1000.00", memo = "INV 2026-0412", sts = "CLR", txn_id = "T-1" } = {}): RawDeposit {
  return { txn_id, amt, memo_txt: memo, posted: "20261027", sts };
}
