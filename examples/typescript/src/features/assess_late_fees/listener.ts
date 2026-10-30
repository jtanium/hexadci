import type { InvoiceRecord } from "../../records/index.ts";
import type { Run } from "./run.ts";

/** The outcomes of a late-fee run. */
export interface Listener {
  invoiceNotProcessed(number: string, reason: string): void;
  lateFeeAdded(invoice: InvoiceRecord, feeCents: number): void;
  invoiceFoundPaid(invoice: InvoiceRecord): void;
  lateFeeNoticeFailed(invoice: InvoiceRecord, reason: string): void;
  earlierNoticeSent(invoice: InvoiceRecord, feeCents: number): void;
  bankUnavailable(reason: string): void;
  runFinished(run: Run): void;
}

export class NullListener implements Listener {
  invoiceNotProcessed(_number: string, _reason: string): void {}
  lateFeeAdded(_invoice: InvoiceRecord, _feeCents: number): void {}
  invoiceFoundPaid(_invoice: InvoiceRecord): void {}
  lateFeeNoticeFailed(_invoice: InvoiceRecord, _reason: string): void {}
  earlierNoticeSent(_invoice: InvoiceRecord, _feeCents: number): void {}
  bankUnavailable(_reason: string): void {}
  runFinished(_run: Run): void {}
}

/** Nightly: only the summary Ops asked for. */
export class SummaryListener extends NullListener {
  override runFinished(run: Run): void {
    if (run.bankUnavailable) {
      console.log(`BANK UNAVAILABLE (${run.bankUnavailable}): no late fees were charged tonight`);
    }
    console.log(`Late fees added: ${run.lateFees.length}, total ${dollars(run.lateFeeTotalCents)}`);
    console.log(`Invoices found already paid: ${run.foundPaid.length}`);
    if (run.earlierNoticesSent.length > 0) {
      console.log(`Notices from earlier runs sent: ${run.earlierNoticesSent.length}`);
    }
    for (const [number, reason] of [...run.notProcessed, ...run.warnings]) console.log(`  ${number}: ${reason}`);
  }
}

/** Single customer at the command line: narrate everything. */
export class PrintingListener extends SummaryListener {
  override invoiceNotProcessed(number: string, reason: string): void {
    console.log(`Could not process ${number}: ${reason}`);
  }

  override lateFeeAdded(invoice: InvoiceRecord, feeCents: number): void {
    console.log(`Added ${dollars(feeCents)} late fee to ${invoice.number}`);
  }

  override invoiceFoundPaid(invoice: InvoiceRecord): void {
    console.log(`${invoice.number} was already paid at the bank; marked paid`);
  }

  override lateFeeNoticeFailed(invoice: InvoiceRecord, reason: string): void {
    console.log(`Late fee on ${invoice.number} stands, but the notice failed: ${reason}`);
  }

  override earlierNoticeSent(invoice: InvoiceRecord, feeCents: number): void {
    console.log(`Sent the notice for the earlier ${dollars(feeCents)} late fee on ${invoice.number}`);
  }

  override bankUnavailable(reason: string): void {
    console.log(`Bank unavailable (${reason}); charging nobody`);
  }
}

function dollars(cents: number): string {
  return `$${(cents / 100).toFixed(2)}`;
}
