// Port: tells someone a late fee was added. Only this feature uses it, so it
// lives in the feature folder. Implementations throw NoticeFailed when they
// cannot deliver.
//
// Telling the customer is a business requirement (R6), so the context has no
// default notice: production must pass a real one. NullLateFeeNotice exists for
// previews and tests that say explicitly they do not want notices.
import type { InvoiceRecord } from "../../records/index.ts";

export interface LateFeeNotice {
  lateFeeAdded(args: { to: string; invoice: InvoiceRecord; feeCents: number }): void;
}

export class StdoutLateFeeNotice implements LateFeeNotice {
  lateFeeAdded({ to, invoice, feeCents }: { to: string; invoice: InvoiceRecord; feeCents: number }): void {
    console.log(`Told ${to} about a $${(feeCents / 100).toFixed(2)} late fee on ${invoice.number}`);
  }
}

export class NullLateFeeNotice implements LateFeeNotice {
  lateFeeAdded(): void {
    // no-op
  }
}
