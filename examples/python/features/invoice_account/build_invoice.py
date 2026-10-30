class BuildInvoice:
    """An invoice is dated the day it is built, addressed to the account's billing
    recipients, and lists every uninvoiced charge on its own line, so the total is
    exactly what the account owes for the period. (Business rule R2.)"""

    @classmethod
    def call(cls, *, invoice, account, charges, on):
        return cls(invoice=invoice, account=account, charges=charges, on=on)()

    def __init__(self, *, invoice, account, charges, on):
        self._invoice = invoice
        self._account = account
        self._charges = charges
        self._on = on

    def __call__(self):
        self._invoice.date(self._on)
        self._invoice.address_to(self._account.recipients())
        for charge in self._charges:
            self._invoice.add_line(description=charge.description, amount_cents=charge.amount_cents)

        return self._invoice
