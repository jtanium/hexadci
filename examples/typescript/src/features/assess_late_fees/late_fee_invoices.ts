import type { InvoiceRecord, LateFee } from "../../records/index.ts";
import type { Customer } from "./customers.ts";
import type { Deposit } from "./retrieve_deposits.ts";

export const DAYS_PAST_DUE_BEFORE_A_FEE = 30;
export const DAYS_BETWEEN_FEES = 30;
export const MINIMUM_FEE_CENTS = 500;

const DAY_MS = 24 * 60 * 60 * 1000;

function daysBetween(earlier: Date, later: Date): number {
  return Math.round((later.getTime() - earlier.getTime()) / DAY_MS);
}

export interface LateFeeInvoice {
  readonly customer: Customer;
  readonly number: string;
  // The return type tells the compiler what the business rule already says:
  // only a chargeable invoice is ever due a late fee. No `instanceof` needed.
  dueForLateFee(on: Date): this is ChargeableInvoice;
  unsentLateFees(): LateFee[];
  markNoticeSent(fee: LateFee): void;
  unwrap(): InvoiceRecord;
}

/**
 * What every invoice role in this feature shares: its number, its customer,
 * and the notices owed for fees already added.
 */
abstract class BaseLateFeeInvoice implements LateFeeInvoice {
  readonly customer: Customer;
  protected readonly record: InvoiceRecord;

  constructor(record: InvoiceRecord, customer: Customer) {
    this.record = record;
    this.customer = customer;
  }

  get number(): string {
    return this.record.number ?? "";
  }

  abstract dueForLateFee(on: Date): this is ChargeableInvoice;

  unsentLateFees(): LateFee[] {
    return this.record.lateFees.filter((fee) => !fee.noticeSent);
  }

  markNoticeSent(fee: LateFee): void {
    fee.noticeSent = true;
    this.record.save();
  }

  unwrap(): InvoiceRecord {
    return this.record;
  }
}

/** The invoice, in the role of "an open invoice that may owe a late fee". */
export class ChargeableInvoice extends BaseLateFeeInvoice {
  /**
   * An invoice owes a late fee once it is more than 30 days past due, and
   * then at most once every 30 days, so a customer is never charged twice for
   * the same month of lateness. (Business rule R1.)
   */
  dueForLateFee(on: Date): this is ChargeableInvoice {
    return this.moreThan30DaysPastDue(on) && this.noLateFeeInTheLast30Days(on);
  }

  /**
   * A late fee is 1.5% of what the customer owes, but never less than $5.00,
   * so small balances still carry a meaningful fee. Half a cent rounds up.
   * (Business rule R3.)
   */
  get lateFeeCents(): number {
    return Math.max(this.oneAndAHalfPercentOfTheBalance(), MINIMUM_FEE_CENTS);
  }

  /**
   * A customer who has already paid should not be charged a fee. The invoice
   * counts as paid when a cleared deposit names it and covers the balance. A
   * pending deposit does not count yet. One bank transaction can pay only one
   * invoice, even when the bank reports it for two customers who share an
   * account. (Business rule R4.)
   */
  coveringDeposit(deposits: Deposit[], alreadyApplied: Set<string>): Deposit | undefined {
    return deposits.find(
      (deposit) =>
        deposit.cleared &&
        this.coveredBy(deposit) &&
        this.namedIn(deposit) &&
        !alreadyApplied.has(deposit.transactionId),
    );
  }

  addLateFee(feeCents: number, on: Date): LateFee {
    const fee: LateFee = { amountCents: feeCents, assessedOn: on, noticeSent: false };
    this.record.lateFees.push(fee);
    // DECISION D1: the fee becomes part of what the customer owes, so later fees
    // are figured on it and a deposit must cover it too. Confirm with Finance.
    this.record.balanceCents += feeCents;
    this.record.save();
    return fee;
  }

  markPaid(): void {
    this.record.status = "paid";
    this.record.save();
  }

  // How our records answer those questions: dates, money, and memo text.

  private moreThan30DaysPastDue(on: Date): boolean {
    if (!this.record.dueDate) throw new TypeError(`invoice ${this.number} has no due date`);
    return daysBetween(this.record.dueDate, on) > DAYS_PAST_DUE_BEFORE_A_FEE;
  }

  private noLateFeeInTheLast30Days(on: Date): boolean {
    return this.record.lateFees.every((fee) => daysBetween(fee.assessedOn, on) >= DAYS_BETWEEN_FEES);
  }

  private oneAndAHalfPercentOfTheBalance(): number {
    return Math.floor((this.record.balanceCents * 15 + 500) / 1000); // 1.5%, rounding half a cent up
  }

  private coveredBy(deposit: Deposit): boolean {
    return deposit.amountCents >= this.record.balanceCents;
  }

  private namedIn(deposit: Deposit): boolean {
    const tokens = deposit.memo.match(/[A-Za-z0-9-]+/g) ?? [];
    return tokens.some((token) => token.toLowerCase() === this.number.toLowerCase());
  }
}

/**
 * Customers on a payment plan have already agreed a schedule with Finance,
 * so they never get late fees, and their invoices are not even checked at the
 * bank. (Business rule R2.)
 */
export class PaymentPlanInvoice extends BaseLateFeeInvoice {
  dueForLateFee(): this is ChargeableInvoice {
    return false;
  }
}
