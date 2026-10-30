from records import Account, Contact
from ports import Notifier


class BillableAccount:
    """The account, in the role of "the one being invoiced"."""

    def __init__(self, account: Account):
        self._account = account

    @property
    def id(self) -> int:
        return self._account.id

    @property
    def past_invoice_totals_cents(self) -> list[int]:
        return self._account.past_invoice_totals_cents

    def recipients(self) -> list[Contact]:
        """Invoices go to the people the account asked us to bill. If it named no
        billing contacts, they go to the company's own email address; if there is
        none, to everyone we have on file, so the invoice always reaches someone.
        (Business rule R3.)"""
        return self._billing_contacts() or self._company_address() or self._account.contacts

    def _billing_contacts(self) -> list[Contact]:
        return self._account.billing_contacts

    def _company_address(self) -> list[Contact]:
        if not self._account.company_email:
            return []
        return [Contact(name=self._account.name, email=self._account.company_email)]

    def unwrap(self) -> Account:
        return self._account


class DirectBilledAccount(BillableAccount):
    def __init__(self, account: Account, *, notifier: Notifier):
        super().__init__(account)
        self._notifier = notifier

    def notify_of_invoice(self, invoice) -> None:
        self._notifier.invoice_ready(recipients=self.recipients(), invoice=invoice.unwrap())


class ResellerBilledAccount(BillableAccount):
    def notify_of_invoice(self, invoice) -> None:
        """The reseller sends this account its invoices and owns the relationship,
        so we never contact the account directly. (Business rule R6.)"""
