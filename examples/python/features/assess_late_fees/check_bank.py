from .errors import RecordProblem, UnrecognizedDeposit
from .retrieve_deposits import RetrieveDeposits


class CheckBank:
    """Checking the bank means: fetch recent deposits for every customer with an
    invoice due a late fee, before anything is changed.

    BankUnavailable is deliberately not caught: the context decides what an
    outage means for the run. An unreadable deposit only affects that customer,
    so it is kept and raised when their deposits are asked for."""

    @classmethod
    def call(cls, *, invoices, bank) -> "BankCheck":
        return cls(invoices=invoices, bank=bank)()

    def __init__(self, *, invoices, bank):
        self._invoices = invoices
        self._bank = bank

    def __call__(self) -> "BankCheck":
        customers = {invoice.customer.id: invoice.customer for invoice in self._invoices}
        return BankCheck({customer_id: self._deposits_for(customer) for customer_id, customer in customers.items()})

    def _deposits_for(self, customer):
        try:
            return RetrieveDeposits.call(bank=self._bank, bank_account_number=customer.bank_account_number)
        except UnrecognizedDeposit as problem:
            return problem


class BankCheck:
    def __init__(self, deposits_by_customer_id):
        self._deposits_by_customer_id = deposits_by_customer_id

    def deposits_for(self, customer):
        deposits = self._deposits_by_customer_id[customer.id]
        if isinstance(deposits, RecordProblem):
            raise deposits
        return deposits
