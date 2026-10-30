from datetime import date

from ports import Notifier
from records import Account, Charge, InvoiceRecord

from .billable_accounts import DirectBilledAccount, ResellerBilledAccount
from .build_invoice import BuildInvoice
from .draft_invoice import DraftInvoice
from .listener import Listener, NullListener


class Context:
    @classmethod
    def call(cls, *, account: Account, charges: list[Charge], notifier: Notifier,
             on: date | None = None, listener: Listener | None = None) -> InvoiceRecord | None:
        return cls(account=account, charges=charges, notifier=notifier,
                   on=on or date.today(), listener=listener or NullListener())()

    def __init__(self, *, account, charges, notifier, on, listener):
        self._account = self._cast_account(account, notifier)
        self._charges = charges
        self._on = on
        self._listener = listener

    # To invoice an account:
    #   1. if the account has no uninvoiced charges, there is nothing to do
    #   2. build a draft invoice from the charges
    #   3. if its total is far out of line with past invoices, hold it for review
    #   4. otherwise finalize it and notify the account
    def __call__(self) -> InvoiceRecord | None:
        # An account with nothing new to bill gets no invoice at all, not an empty
        # one. (Business rule R1.)
        if not self._charges:
            self._listener.nothing_to_invoice(self._account.unwrap())
            return None

        invoice = DraftInvoice.new_for(self._account)
        BuildInvoice.call(invoice=invoice, account=self._account, charges=self._charges, on=self._on)

        if invoice.in_bounds(self._account.past_invoice_totals_cents):
            invoice.finalize()
            self._account.notify_of_invoice(invoice)
            self._listener.invoice_finalized(invoice.unwrap())
        else:
            # A held invoice waits for a person to review it, so nobody is told
            # about it yet. (Business rule R5.)
            invoice.hold()
            self._listener.invoice_held(invoice.unwrap())

        return invoice.unwrap()  # control our return value

    @staticmethod
    def _cast_account(account, notifier):
        if account.billed_through_reseller:
            return ResellerBilledAccount(account)
        return DirectBilledAccount(account, notifier=notifier)
