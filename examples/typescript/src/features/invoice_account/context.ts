import type { Account, Charge, InvoiceRecord } from "../../records/index.ts";
import type { Notifier } from "../../ports/notifier.ts";
import { BillableAccount, DirectBilledAccount, ResellerBilledAccount } from "./billable_accounts.ts";
import { BuildInvoice } from "./build_invoice.ts";
import { DraftInvoice } from "./draft_invoice.ts";
import { NullListener } from "./listener.ts";
import type { Listener } from "./listener.ts";

export interface InvoiceAccountArgs {
  account: Account;
  charges: Charge[];
  notifier: Notifier;
  on?: Date;
  listener?: Listener;
}

export class Context {
  private readonly account: BillableAccount;
  private readonly charges: Charge[];
  private readonly on: Date;
  private readonly listener: Listener;

  static call(args: InvoiceAccountArgs): InvoiceRecord | null {
    return new Context(args).call();
  }

  constructor({ account, charges, notifier, on = new Date(), listener = new NullListener() }: InvoiceAccountArgs) {
    this.account = Context.castAccount(account, notifier);
    this.charges = charges;
    this.on = on;
    this.listener = listener;
  }

  // To invoice an account:
  //   1. if the account has no uninvoiced charges, there is nothing to do
  //   2. build a draft invoice from the charges
  //   3. if its total is far out of line with past invoices, hold it for review
  //   4. otherwise finalize it and notify the account
  call(): InvoiceRecord | null {
    // An account with nothing new to bill gets no invoice at all, not an empty
    // one. (Business rule R1.)
    if (this.charges.length === 0) {
      this.listener.nothingToInvoice(this.account.unwrap());
      return null;
    }

    const invoice = DraftInvoice.newFor(this.account);
    BuildInvoice.call({ invoice, account: this.account, charges: this.charges, on: this.on });

    if (invoice.inBounds(this.account.pastInvoiceTotalsCents)) {
      invoice.finalize();
      this.account.notifyOfInvoice(invoice);
      this.listener.invoiceFinalized(invoice.unwrap());
    } else {
      // A held invoice waits for a person to review it, so nobody is told
      // about it yet. (Business rule R5.)
      invoice.hold();
      this.listener.invoiceHeld(invoice.unwrap());
    }

    return invoice.unwrap(); // control our return value
  }

  private static castAccount(account: Account, notifier: Notifier): BillableAccount {
    if (account.billedThroughReseller) return new ResellerBilledAccount(account);
    return new DirectBilledAccount(account, notifier);
  }
}
