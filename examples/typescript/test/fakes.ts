import type { Account, Charge, Contact, InvoiceRecord } from "../src/records/index.ts";
import type { Notifier } from "../src/ports/notifier.ts";
import type { Listener } from "../src/features/invoice_account/index.ts";

type Event =
  | ["nothingToInvoice", Account]
  | ["invoiceFinalized", InvoiceRecord]
  | ["invoiceHeld", InvoiceRecord];

/** Records every message it receives, so tests can assert on outcomes. */
export class RecordingListener implements Listener {
  events: Event[] = [];

  nothingToInvoice(account: Account): void {
    this.events.push(["nothingToInvoice", account]);
  }

  invoiceFinalized(invoice: InvoiceRecord): void {
    this.events.push(["invoiceFinalized", invoice]);
  }

  invoiceHeld(invoice: InvoiceRecord): void {
    this.events.push(["invoiceHeld", invoice]);
  }
}

export class FakeNotifier implements Notifier {
  sent: { recipients: Contact[]; invoice: InvoiceRecord }[] = [];

  invoiceReady(args: { recipients: Contact[]; invoice: InvoiceRecord }): void {
    this.sent.push(args);
  }
}

export function account(overrides: Partial<Account> = {}): Account {
  return {
    id: 7,
    name: "Example Coffee",
    billingContacts: [],
    contacts: [],
    billedThroughReseller: false,
    pastInvoiceTotalsCents: [],
    ...overrides,
  };
}

export function contact(name: string): Contact {
  return { name, email: `${name.toLowerCase()}@example.test` };
}

export function charge(amountCents: number, description = "Fee"): Charge {
  return { description, amountCents };
}
