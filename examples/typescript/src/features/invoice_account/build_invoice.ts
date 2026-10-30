import type { Charge } from "../../records/index.ts";
import type { BillableAccount } from "./billable_accounts.ts";
import type { DraftInvoice } from "./draft_invoice.ts";

interface BuildInvoiceArgs {
  invoice: DraftInvoice;
  account: BillableAccount;
  charges: Charge[];
  on: Date;
}

/**
 * An invoice is dated the day it is built, addressed to the account's billing
 * recipients, and lists every uninvoiced charge on its own line, so the total is
 * exactly what the account owes for the period. (Business rule R2.)
 */
export class BuildInvoice {
  private readonly args: BuildInvoiceArgs;

  static call(args: BuildInvoiceArgs): DraftInvoice {
    return new BuildInvoice(args).call();
  }

  constructor(args: BuildInvoiceArgs) {
    this.args = args;
  }

  call(): DraftInvoice {
    const { invoice, account, charges, on } = this.args;

    invoice.date(on);
    invoice.addressTo(account.recipients());
    for (const charge of charges) {
      invoice.addLine({ description: charge.description, amountCents: charge.amountCents });
    }

    return invoice;
  }
}
