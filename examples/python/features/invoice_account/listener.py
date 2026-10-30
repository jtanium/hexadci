from typing import Protocol

from records import Account, InvoiceRecord


class Listener(Protocol):
    """The outcomes of invoicing an account. A web handler usually implements this itself."""

    def nothing_to_invoice(self, account: Account) -> None: ...
    def invoice_finalized(self, invoice: InvoiceRecord) -> None: ...
    def invoice_held(self, invoice: InvoiceRecord) -> None: ...


class NullListener:
    def nothing_to_invoice(self, account):
        pass  # no-op

    def invoice_finalized(self, invoice):
        pass  # no-op

    def invoice_held(self, invoice):
        pass  # no-op


class PrintingListener:
    """Turns on output for this feature only, e.g. from a CLI or while debugging."""

    def nothing_to_invoice(self, account):
        print(f"Nothing to invoice for {account.name}")

    def invoice_finalized(self, invoice):
        print(f"Finalized invoice for account {invoice.account_id}: {_dollars(invoice.total_cents)}")

    def invoice_held(self, invoice):
        print(f"Held invoice for account {invoice.account_id} for review: {_dollars(invoice.total_cents)}")


def _dollars(cents: int) -> str:
    return f"${cents / 100:.2f}"
