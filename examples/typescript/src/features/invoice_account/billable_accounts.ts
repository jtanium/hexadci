import type { Account, Contact } from "../../records/index.ts";
import type { Notifier } from "../../ports/notifier.ts";
import type { DraftInvoice } from "./draft_invoice.ts";

/** The account, in the role of "the one being invoiced". */
export abstract class BillableAccount {
  protected readonly account: Account;

  constructor(account: Account) {
    this.account = account;
  }

  get id(): number {
    return this.account.id;
  }

  get pastInvoiceTotalsCents(): number[] {
    return this.account.pastInvoiceTotalsCents;
  }

  /**
   * Invoices go to the people the account asked us to bill. If it named no
   * billing contacts, they go to the company's own email address; if there is
   * none, to everyone we have on file, so the invoice always reaches someone.
   * (Business rule R3.)
   */
  recipients(): Contact[] {
    return this.billingContacts() ?? this.companyAddress() ?? this.account.contacts;
  }

  private billingContacts(): Contact[] | undefined {
    return this.account.billingContacts.length > 0 ? this.account.billingContacts : undefined;
  }

  private companyAddress(): Contact[] | undefined {
    if (!this.account.companyEmail) return undefined;
    return [{ name: this.account.name, email: this.account.companyEmail }];
  }

  abstract notifyOfInvoice(invoice: DraftInvoice): void;

  unwrap(): Account {
    return this.account;
  }
}

export class DirectBilledAccount extends BillableAccount {
  private readonly notifier: Notifier;

  constructor(account: Account, notifier: Notifier) {
    super(account);
    this.notifier = notifier;
  }

  notifyOfInvoice(invoice: DraftInvoice): void {
    this.notifier.invoiceReady({ recipients: this.recipients(), invoice: invoice.unwrap() });
  }
}

export class ResellerBilledAccount extends BillableAccount {
  /**
   * The reseller sends this account its invoices and owns the relationship,
   * so we never contact the account directly. (Business rule R6.)
   */
  notifyOfInvoice(): void {
    // no-op
  }
}
