// Stand-ins for persistence-backed models (an ORM entity, a repository row, etc.).
//
// They hold data and broadly useful accessors, and nothing specific to any one
// business operation. Operation-specific behavior lives in role classes inside
// each feature folder.

export interface Contact {
  name: string;
  email: string;
}

export interface Charge {
  description: string;
  amountCents: number;
}

export interface Account {
  id: number;
  name: string;
  companyEmail?: string;
  billingContacts: Contact[];
  contacts: Contact[];
  billedThroughReseller: boolean;
  resellerEmail?: string;
  onPaymentPlan?: boolean;
  bankAccountNumber?: string;
  pastInvoiceTotalsCents: number[];
}

export interface InvoiceLine {
  description: string;
  amountCents: number;
}

export interface LateFee {
  amountCents: number;
  assessedOn: Date;
  noticeSent?: boolean; // false or missing until the customer has been told
}

export type InvoiceStatus = "draft" | "open" | "held" | "final" | "paid";

export class InvoiceRecord {
  accountId: number;
  number?: string;
  invoiceDate?: Date;
  dueDate?: Date;
  recipients: Contact[] = [];
  lines: InvoiceLine[] = [];
  totalCents = 0;
  balanceCents = 0;
  lateFees: LateFee[] = [];
  status: InvoiceStatus = "draft";
  saved = false;

  constructor(
    accountId: number,
    options: { number?: string; dueDate?: Date; balanceCents?: number; status?: InvoiceStatus } = {},
  ) {
    this.accountId = accountId;
    this.number = options.number;
    this.dueDate = options.dueDate;
    this.balanceCents = options.balanceCents ?? 0;
    this.status = options.status ?? "draft";
  }

  save(): void {
    this.saved = true;
  }
}
