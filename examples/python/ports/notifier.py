"""Port: tells people that something is ready for them.

Implementations decide how (email, SMS, a queue). Business operations only
know the message they send.
"""
from typing import Protocol, Sequence

from records import Contact, InvoiceRecord


class Notifier(Protocol):
    def invoice_ready(self, *, recipients: Sequence[Contact], invoice: InvoiceRecord) -> None: ...


class StdoutNotifier:
    def invoice_ready(self, *, recipients, invoice):
        emails = ", ".join(r.email for r in recipients)
        print(f"Notified {emails} of invoice for account {invoice.account_id}")


class NullNotifier:
    def invoice_ready(self, *, recipients, invoice):
        pass  # no-op
