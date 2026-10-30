import type { Account, InvoiceRecord } from "../../records/index.ts";

/** The outcomes of invoicing an account. A web handler usually implements this itself. */
export interface Listener {
  nothingToInvoice(account: Account): void;
  invoiceFinalized(invoice: InvoiceRecord): void;
  invoiceHeld(invoice: InvoiceRecord): void;
}

export class NullListener implements Listener {
  nothingToInvoice(): void {
    // no-op
  }

  invoiceFinalized(): void {
    // no-op
  }

  invoiceHeld(): void {
    // no-op
  }
}

/** Turns on output for this feature only, e.g. from a CLI or while debugging. */
export class PrintingListener implements Listener {
  nothingToInvoice(account: Account): void {
    console.log(`Nothing to invoice for ${account.name}`);
  }

  invoiceFinalized(invoice: InvoiceRecord): void {
    console.log(`Finalized invoice for account ${invoice.accountId}: ${dollars(invoice.totalCents)}`);
  }

  invoiceHeld(invoice: InvoiceRecord): void {
    console.log(`Held invoice for account ${invoice.accountId} for review: ${dollars(invoice.totalCents)}`);
  }
}

function dollars(cents: number): string {
  return `$${(cents / 100).toFixed(2)}`;
}
