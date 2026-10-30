import { ImpossibleRun } from "./errors.ts";
import { MINIMUM_FEE_CENTS } from "./late_fee_invoices.ts";

/** The result of one run: what Ops sees in the nightly summary. */
export class Run {
  lateFees: [invoiceNumber: string, feeCents: number][] = [];
  foundPaid: string[] = [];
  notProcessed: [invoiceNumber: string, reason: string][] = [];
  warnings: [invoiceNumber: string, reason: string][] = [];
  earlierNoticesSent: string[] = []; // invoice numbers (R9)
  bankUnavailable: string | null = null;

  get lateFeeTotalCents(): number {
    return this.lateFees.reduce((sum, [, cents]) => sum + cents, 0);
  }

  /**
   * Impossible results (N1-N3 in RULES.md) mean something upstream is wrong; stop loudly.
   *
   * This is a diagnostic, not the guard: by the time it runs, changes have been
   * made. The guards are the bank gate (R5) and duplicate rejection (R8), which
   * act before anything changes.
   */
  checkTotals(): void {
    if (this.bankUnavailable && (this.lateFees.length > 0 || this.foundPaid.length > 0)) {
      throw new ImpossibleRun("invoices were changed although the bank was unavailable");
    }
    if (this.lateFees.some(([, cents]) => cents < MINIMUM_FEE_CENTS)) {
      throw new ImpossibleRun(`a late fee is below the minimum: ${JSON.stringify(this.lateFees)}`);
    }

    const changed = [...this.lateFees.map(([n]) => n), ...this.foundPaid];
    const duplicates = changed.filter((number, index) => changed.indexOf(number) !== index);
    if (duplicates.length > 0) {
      throw new ImpossibleRun(`invoices changed more than once: ${JSON.stringify([...new Set(duplicates)])}`);
    }
  }
}
