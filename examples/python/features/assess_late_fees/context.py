from datetime import date

from ports.bank import Bank, BankUnavailable
from records import Account, InvoiceRecord, LateFee

from .check_bank import CheckBank
from .customers import DirectCustomer, ResellerCustomer
from .errors import NoticeFailed, RecordProblem
from .late_fee_invoices import ChargeableInvoice, PaymentPlanInvoice
from .late_fee_notice import LateFeeNotice
from .listener import Listener, NullListener
from .run import Run


class Context:
    """Assess late fees on a set of open invoices. The nightly job passes every
    open invoice; the single-account CLI passes one account's. Same rules."""

    @classmethod
    def call(cls, *, invoices: list[InvoiceRecord], accounts: list[Account], bank: Bank,
             notice: LateFeeNotice, on: date | None = None, listener: Listener | None = None) -> Run:
        # `notice` has no default: telling the customer is required (R6).
        # The listener is diagnostic, so it defaults to doing nothing.
        return cls(invoices=invoices, accounts=accounts, bank=bank, notice=notice,
                   on=on or date.today(), listener=listener or NullListener())()

    def __init__(self, *, invoices, accounts, bank, notice, on, listener):
        self._bank = bank
        self._on = on
        self._listener = listener
        self._run = Run()
        self._applied_transaction_ids: set[str] = set()

        # An invoice listed twice is still only one invoice: handle it once and
        # report the repeat, before anything can be charged or sent. (Business rule R8.)
        seen, unique, self._repeats = set(), [], []
        for record in invoices:
            (self._repeats if record.number in seen else unique).append(record)
            seen.add(record.number)

        customers = {account.id: self._cast_customer(account, notice) for account in accounts}
        self._uncastable = [record for record in unique if record.account_id not in customers]
        self._invoices = [self._cast_invoice(record, customers[record.account_id])
                          for record in unique if record.account_id in customers]

    # To assess late fees:
    #   1. report any invoice whose account we cannot find, or that is listed more
    #      than once; carry on with the rest
    #   2. send any late-fee notice from an earlier run that did not go out
    #   3. pick the invoices due a late fee today
    #   4. check the bank for every customer with such an invoice, before
    #      changing anything; if the bank is down, charge nobody tonight
    #   5. for each due invoice: if a cleared deposit already covers it, mark it
    #      paid; otherwise add a late fee and tell whoever handles the customer's
    #      billing. One bad invoice does not stop the others
    #   6. sanity-check the results and report the summary
    def __call__(self) -> Run:
        for record in self._repeats:
            self._not_processed(record.number, "listed more than once in this run")
        for record in self._uncastable:
            self._not_processed(record.number, f"no account {record.account_id}")

        self._send_earlier_notices()

        due = [invoice for invoice in self._invoices if invoice.due_for_late_fee(self._on)]

        try:
            bank_check = CheckBank.call(invoices=due, bank=self._bank)
        except BankUnavailable as outage:
            # Without the bank we can't tell who has already paid, so nobody is
            # charged or marked paid tonight. (Business rule R5.)
            self._run.bank_unavailable = str(outage)
            self._listener.bank_unavailable(str(outage))
            return self._finish()

        for invoice in due:
            self._settle(invoice, bank_check)

        return self._finish()

    def _send_earlier_notices(self) -> None:
        # A customer charged a fee must hear about it. A notice that failed is sent
        # again on every run until it goes out. (Business rule R9.)
        for invoice in self._invoices:
            for fee in invoice.unsent_late_fees():
                if self._tell_customer(invoice, fee):
                    self._run.earlier_notices_sent.append(invoice.number)
                    self._listener.earlier_notice_sent(invoice.unwrap(), fee.amount_cents)

    def _settle(self, invoice, bank_check) -> None:
        try:
            deposit = invoice.covering_deposit(bank_check.deposits_for(invoice.customer),
                                               already_applied=self._applied_transaction_ids)
            if deposit:
                invoice.mark_paid()
                self._applied_transaction_ids.add(deposit.transaction_id)
                self._run.found_paid.append(invoice.number)
                self._listener.invoice_found_paid(invoice.unwrap())
            else:
                fee = invoice.add_late_fee(invoice.late_fee_cents, on=self._on)
                self._run.late_fees.append((invoice.number, fee.amount_cents))
                self._listener.late_fee_added(invoice.unwrap(), fee.amount_cents)
                self._tell_customer(invoice, fee)
        except RecordProblem as problem:
            # One invoice's problem is reported and the others carry on. (Business rule R7.)
            self._not_processed(invoice.number, str(problem))

    def _tell_customer(self, invoice, fee: LateFee) -> bool:
        try:
            invoice.customer.notify_of_late_fee(invoice, fee.amount_cents)
        except NoticeFailed as failure:
            # The fee stands; the notice stays unsent and is retried next run (R9).
            self._run.warnings.append((invoice.number, f"late fee notice failed, will retry next run: {failure}"))
            self._listener.late_fee_notice_failed(invoice.unwrap(), str(failure))
            return False
        invoice.mark_notice_sent(fee)
        return True

    def _not_processed(self, number, reason) -> None:
        self._run.not_processed.append((number, reason))
        self._listener.invoice_not_processed(number, reason)

    def _finish(self) -> Run:
        self._run.check_totals()
        self._listener.run_finished(self._run)
        return self._run  # control our return value

    @staticmethod
    def _cast_customer(account, notice):
        if account.billed_through_reseller:
            return ResellerCustomer(account, notice=notice)
        return DirectCustomer(account, notice=notice)

    @staticmethod
    def _cast_invoice(record, customer):
        if customer.on_payment_plan:
            return PaymentPlanInvoice(record, customer=customer)
        return ChargeableInvoice(record, customer=customer)
