// Port: tells people that something is ready for them.
//
// Implementations decide how (email, SMS, a queue). Business operations only
// know the message they send.
import type { Contact, InvoiceRecord } from "../records/index.ts";

export interface Notifier {
  invoiceReady(args: { recipients: Contact[]; invoice: InvoiceRecord }): void;
}

export class StdoutNotifier implements Notifier {
  invoiceReady({ recipients, invoice }: { recipients: Contact[]; invoice: InvoiceRecord }): void {
    const emails = recipients.map((r) => r.email).join(", ");
    console.log(`Notified ${emails} of invoice for account ${invoice.accountId}`);
  }
}

export class NullNotifier implements Notifier {
  invoiceReady(): void {
    // no-op
  }
}
