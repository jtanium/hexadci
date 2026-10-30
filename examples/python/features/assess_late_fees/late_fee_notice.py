"""Port: tells someone a late fee was added. Only this feature uses it, so it
lives in the feature folder. Implementations raise NoticeFailed when they cannot
deliver.

Telling the customer is a business requirement (R6), so the context has no
default notice: production must pass a real one. NullLateFeeNotice exists for
previews and tests that say explicitly they do not want notices."""
from typing import Protocol

from records import InvoiceRecord


class LateFeeNotice(Protocol):
    def late_fee_added(self, *, to: str, invoice: InvoiceRecord, fee_cents: int) -> None: ...


class StdoutLateFeeNotice:
    def late_fee_added(self, *, to, invoice, fee_cents):
        print(f"Told {to} about a ${fee_cents / 100:.2f} late fee on {invoice.number}")


class NullLateFeeNotice:
    def late_fee_added(self, *, to, invoice, fee_cents):
        pass  # no-op
