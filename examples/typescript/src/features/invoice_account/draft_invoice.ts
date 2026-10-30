import { InvoiceRecord } from "../../records/index.ts";
import type { Contact } from "../../records/index.ts";

// Differences this small are never worth a human review.
const SMALL_DIFFERENCE_CENTS = 500;
// Fewer past invoices than this is too little history to judge an invoice by.
const INVOICES_NEEDED_FOR_A_HISTORY = 3;

/** The invoice record, in the role of "the invoice being prepared". */
export class DraftInvoice {
  private readonly record: InvoiceRecord;

  static newFor(account: { id: number }): DraftInvoice {
    return new DraftInvoice(new InvoiceRecord(account.id));
  }

  constructor(record: InvoiceRecord) {
    this.record = record;
  }

  date(on: Date): void {
    this.record.invoiceDate = on;
  }

  addressTo(recipients: Contact[]): void {
    this.record.recipients = [...recipients];
  }

  addLine({ description, amountCents }: { description: string; amountCents: number }): void {
    this.record.lines.push({ description, amountCents });
    this.record.totalCents += amountCents;
  }

  get totalCents(): number {
    return this.record.totalCents;
  }

  /**
   * An invoice goes out without review unless it is far out of line with what
   * this account usually pays. A new account has too little history to judge,
   * so its invoices always go out. Otherwise an invoice is in line when it is
   * within $5.00 of the account's average, or within the normal spread of its
   * past invoices (three standard deviations). (Business rule R4.)
   */
  inBounds(pastTotalsCents: number[]): boolean {
    return (
      tooLittleHistory(pastTotalsCents) ||
      this.closeToAverage(pastTotalsCents) ||
      this.withinNormalSpread(pastTotalsCents)
    );
  }

  private closeToAverage(pastTotalsCents: number[]): boolean {
    return Math.abs(this.totalCents - mean(pastTotalsCents)) <= SMALL_DIFFERENCE_CENTS;
  }

  private withinNormalSpread(pastTotalsCents: number[]): boolean {
    return Math.abs(this.totalCents - mean(pastTotalsCents)) <= 3 * standardDeviation(pastTotalsCents);
  }

  hold(): void {
    this.record.status = "held";
    this.record.save();
  }

  finalize(): void {
    this.record.status = "final";
    this.record.save();
  }

  unwrap(): InvoiceRecord {
    return this.record;
  }
}

// How "history" and "spread" are measured: arithmetic, not policy.

function tooLittleHistory(pastTotalsCents: number[]): boolean {
  return pastTotalsCents.length < INVOICES_NEEDED_FOR_A_HISTORY;
}

function mean(values: number[]): number {
  return values.reduce((sum, v) => sum + v, 0) / values.length;
}

function standardDeviation(values: number[]): number {
  // DECISION D1: the spread of all past invoices (population standard
  // deviation), not a sample estimate. See RULES.md.
  const average = mean(values);
  return Math.sqrt(values.reduce((sum, v) => sum + (v - average) ** 2, 0) / values.length);
}
