import type { Bank } from "../../ports/bank.ts";
import type { Customer } from "./customers.ts";
import { RecordProblem, UnrecognizedDeposit } from "./errors.ts";
import { RetrieveDeposits } from "./retrieve_deposits.ts";
import type { Deposit } from "./retrieve_deposits.ts";

/**
 * Checking the bank means: fetch recent deposits for every customer with an
 * invoice due a late fee, before anything is changed.
 *
 * BankUnavailable is deliberately not caught: the context decides what an
 * outage means for the run. An unreadable deposit only affects that customer,
 * so it is kept and thrown when their deposits are asked for.
 */
export class CheckBank {
  private readonly invoices: { customer: Customer }[];
  private readonly bank: Bank;

  static call(args: { invoices: { customer: Customer }[]; bank: Bank }): BankCheck {
    return new CheckBank(args).call();
  }

  constructor({ invoices, bank }: { invoices: { customer: Customer }[]; bank: Bank }) {
    this.invoices = invoices;
    this.bank = bank;
  }

  call(): BankCheck {
    const customers = new Map(this.invoices.map((invoice) => [invoice.customer.id, invoice.customer]));
    const deposits = new Map<number, Deposit[] | RecordProblem>();
    for (const [id, customer] of customers) deposits.set(id, this.depositsFor(customer));
    return new BankCheck(deposits);
  }

  private depositsFor(customer: Customer): Deposit[] | RecordProblem {
    try {
      return RetrieveDeposits.call({ bank: this.bank, bankAccountNumber: customer.bankAccountNumber });
    } catch (error) {
      if (error instanceof UnrecognizedDeposit) return error;
      throw error;
    }
  }
}

export class BankCheck {
  private readonly depositsByCustomerId: Map<number, Deposit[] | RecordProblem>;

  constructor(depositsByCustomerId: Map<number, Deposit[] | RecordProblem>) {
    this.depositsByCustomerId = depositsByCustomerId;
  }

  depositsFor(customer: Customer): Deposit[] {
    const deposits = this.depositsByCustomerId.get(customer.id);
    if (deposits === undefined) throw new Error(`customer ${customer.id} was not checked at the bank`);
    if (deposits instanceof RecordProblem) throw deposits;
    return deposits;
  }
}
