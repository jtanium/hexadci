import type { Account, InvoiceRecord } from "../../records/index.ts";
import type { LateFeeNotice } from "./late_fee_notice.ts";

/** The account, in the role of "the customer whose invoice is overdue". */
export abstract class Customer {
  protected readonly account: Account;
  protected readonly notice: LateFeeNotice;

  constructor(account: Account, notice: LateFeeNotice) {
    this.account = account;
    this.notice = notice;
  }

  get id(): number {
    return this.account.id;
  }

  get onPaymentPlan(): boolean {
    return this.account.onPaymentPlan === true;
  }

  get bankAccountNumber(): string {
    return this.account.bankAccountNumber ?? "";
  }

  abstract notifyOfLateFee(invoice: { unwrap(): InvoiceRecord }, feeCents: number): void;

  unwrap(): Account {
    return this.account;
  }
}

export class DirectCustomer extends Customer {
  notifyOfLateFee(invoice: { unwrap(): InvoiceRecord }, feeCents: number): void {
    this.notice.lateFeeAdded({ to: this.account.companyEmail ?? "", invoice: invoice.unwrap(), feeCents });
  }
}

export class ResellerCustomer extends Customer {
  /**
   * A customer who came through a reseller is the reseller's to manage: we
   * tell the reseller about the fee and never contact the customer directly.
   * Everyone else hears from us at their billing address. (Business rule R6.)
   */
  notifyOfLateFee(invoice: { unwrap(): InvoiceRecord }, feeCents: number): void {
    this.notice.lateFeeAdded({ to: this.account.resellerEmail ?? "", invoice: invoice.unwrap(), feeCents });
  }
}
