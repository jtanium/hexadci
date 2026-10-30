from records import Account


class Customer:
    """The account, in the role of "the customer whose invoice is overdue"."""

    def __init__(self, account: Account, *, notice):
        self._account = account
        self._notice = notice

    @property
    def id(self) -> int:
        return self._account.id

    @property
    def on_payment_plan(self) -> bool:
        return self._account.on_payment_plan

    @property
    def bank_account_number(self) -> str | None:
        return self._account.bank_account_number

    def unwrap(self) -> Account:
        return self._account


class DirectCustomer(Customer):
    def notify_of_late_fee(self, invoice, fee_cents: int) -> None:
        self._notice.late_fee_added(to=self._account.company_email, invoice=invoice.unwrap(), fee_cents=fee_cents)


class ResellerCustomer(Customer):
    def notify_of_late_fee(self, invoice, fee_cents: int) -> None:
        """A customer who came through a reseller is the reseller's to manage: we
        tell the reseller about the fee and never contact the customer directly.
        Everyone else hears from us at their billing address. (Business rule R6.)"""
        self._notice.late_fee_added(to=self._account.reseller_email, invoice=invoice.unwrap(), fee_cents=fee_cents)
