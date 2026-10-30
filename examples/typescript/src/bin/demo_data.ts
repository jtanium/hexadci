// Demo data standing in for the database and the bank, so the entry points run.
import type { Bank, RawDeposit } from "../ports/bank.ts";
import { InvoiceRecord } from "../records/index.ts";
import type { Account } from "../records/index.ts";

export const TODAY = new Date(Date.UTC(2026, 9, 29));

function daysAgo(days: number): Date {
  return new Date(TODAY.getTime() - days * 24 * 60 * 60 * 1000);
}

function demoAccount(overrides: Partial<Account> & Pick<Account, "id" | "name">): Account {
  return { billingContacts: [], contacts: [], billedThroughReseller: false, pastInvoiceTotalsCents: [], ...overrides };
}

export const ACCOUNTS: Account[] = [
  demoAccount({ id: 1, name: "Example Coffee", companyEmail: "ap@coffee.test", bankAccountNumber: "000111" }),
  demoAccount({
    id: 2,
    name: "Resold Bakery",
    billedThroughReseller: true,
    resellerEmail: "billing@reseller.test",
    bankAccountNumber: "000222",
  }),
  demoAccount({ id: 3, name: "Planned Books", onPaymentPlan: true, bankAccountNumber: "000333" }),
];

export function openInvoices(): InvoiceRecord[] {
  return [
    new InvoiceRecord(1, { number: "2026-0412", dueDate: daysAgo(45), balanceCents: 100_000, status: "open" }),
    new InvoiceRecord(1, { number: "2026-0415", dueDate: daysAgo(40), balanceCents: 12_000, status: "open" }),
    new InvoiceRecord(2, { number: "2026-0420", dueDate: daysAgo(35), balanceCents: 20_000, status: "open" }),
    new InvoiceRecord(3, { number: "2026-0431", dueDate: daysAgo(90), balanceCents: 50_000, status: "open" }),
  ];
}

export class DemoBank implements Bank {
  private readonly deposits: Record<string, RawDeposit[]> = {
    "000111": [{ txn_id: "T-1001", amt: "120.00", memo_txt: "INV 2026-0415 thanks", posted: "20261027", sts: "CLR" }],
  };

  recentDeposits(bankAccountNumber: string): RawDeposit[] {
    return this.deposits[bankAccountNumber] ?? [];
  }
}
