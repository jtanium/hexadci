import re
from datetime import date

from records import InvoiceRecord, LateFee

DAYS_PAST_DUE_BEFORE_A_FEE = 30
DAYS_BETWEEN_FEES = 30
MINIMUM_FEE_CENTS = 500

_TOKEN = re.compile(r"[A-Za-z0-9-]+")


class _LateFeeInvoice:
    """What every invoice role in this feature shares: its number, its customer,
    and the notices owed for fees already added."""

    def __init__(self, record: InvoiceRecord, *, customer):
        self._record = record
        self.customer = customer

    @property
    def number(self) -> str:
        return self._record.number

    def unsent_late_fees(self) -> list[LateFee]:
        return [fee for fee in self._record.late_fees if not fee.notice_sent]

    def mark_notice_sent(self, fee: LateFee) -> None:
        fee.notice_sent = True
        self._record.save()

    def unwrap(self) -> InvoiceRecord:
        return self._record


class ChargeableInvoice(_LateFeeInvoice):
    """The invoice, in the role of "an open invoice that may owe a late fee"."""

    def due_for_late_fee(self, on: date) -> bool:
        """An invoice owes a late fee once it is more than 30 days past due, and
        then at most once every 30 days, so a customer is never charged twice for
        the same month of lateness. (Business rule R1.)"""
        return self._more_than_30_days_past_due(on) and self._no_late_fee_in_the_last_30_days(on)

    @property
    def late_fee_cents(self) -> int:
        """A late fee is 1.5% of what the customer owes, but never less than $5.00,
        so small balances still carry a meaningful fee. Half a cent rounds up.
        (Business rule R3.)"""
        return max(self._one_and_a_half_percent_of_the_balance(), MINIMUM_FEE_CENTS)

    def covering_deposit(self, deposits, *, already_applied: set[str]):
        """A customer who has already paid should not be charged a fee. The invoice
        counts as paid when a cleared deposit names it and covers the balance. A
        pending deposit does not count yet. One bank transaction can pay only one
        invoice, even when the bank reports it for two customers who share an
        account. (Business rule R4.)"""
        for deposit in deposits:
            if (deposit.cleared
                    and self._covered_by(deposit)
                    and self._named_in(deposit)
                    and deposit.transaction_id not in already_applied):
                return deposit
        return None

    def add_late_fee(self, fee_cents: int, *, on: date) -> LateFee:
        fee = LateFee(amount_cents=fee_cents, assessed_on=on)
        self._record.late_fees.append(fee)
        # DECISION D1: the fee becomes part of what the customer owes, so later fees
        # are figured on it and a deposit must cover it too. Confirm with Finance.
        self._record.balance_cents += fee_cents
        self._record.save()
        return fee

    def mark_paid(self) -> None:
        self._record.status = "paid"
        self._record.save()

    # How our records answer those questions: dates, money, and memo text.

    def _more_than_30_days_past_due(self, on: date) -> bool:
        return (on - self._record.due_date).days > DAYS_PAST_DUE_BEFORE_A_FEE

    def _no_late_fee_in_the_last_30_days(self, on: date) -> bool:
        return all((on - fee.assessed_on).days >= DAYS_BETWEEN_FEES for fee in self._record.late_fees)

    def _one_and_a_half_percent_of_the_balance(self) -> int:
        return (self._record.balance_cents * 15 + 500) // 1000  # 1.5%, rounding half a cent up

    def _covered_by(self, deposit) -> bool:
        return deposit.amount_cents >= self._record.balance_cents

    def _named_in(self, deposit) -> bool:
        return any(token.casefold() == self.number.casefold() for token in _TOKEN.findall(deposit.memo))


class PaymentPlanInvoice(_LateFeeInvoice):
    """Customers on a payment plan have already agreed a schedule with Finance,
    so they never get late fees, and their invoices are not even checked at the
    bank. (Business rule R2.)"""

    def due_for_late_fee(self, on: date) -> bool:
        return False
