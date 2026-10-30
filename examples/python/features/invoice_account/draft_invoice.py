import math

from records import InvoiceRecord

# Differences this small are never worth a human review.
SMALL_DIFFERENCE_CENTS = 500
# Fewer past invoices than this is too little history to judge an invoice by.
INVOICES_NEEDED_FOR_A_HISTORY = 3


class DraftInvoice:
    """The invoice record, in the role of "the invoice being prepared"."""

    @classmethod
    def new_for(cls, account) -> "DraftInvoice":
        return cls(InvoiceRecord(account_id=account.id))

    def __init__(self, record: InvoiceRecord):
        self._record = record

    def date(self, on) -> None:
        self._record.invoice_date = on

    def address_to(self, recipients) -> None:
        self._record.recipients = list(recipients)

    def add_line(self, *, description: str, amount_cents: int) -> None:
        self._record.lines.append({"description": description, "amount_cents": amount_cents})
        self._record.total_cents += amount_cents

    @property
    def total_cents(self) -> int:
        return self._record.total_cents

    def in_bounds(self, past_totals_cents: list[int]) -> bool:
        """An invoice goes out without review unless it is far out of line with what
        this account usually pays. A new account has too little history to judge,
        so its invoices always go out. Otherwise an invoice is in line when it is
        within $5.00 of the account's average, or within the normal spread of its
        past invoices (three standard deviations). (Business rule R4.)"""
        return (_too_little_history(past_totals_cents)
                or self._close_to_average(past_totals_cents)
                or self._within_normal_spread(past_totals_cents))

    def _close_to_average(self, past_totals_cents: list[int]) -> bool:
        return abs(self.total_cents - _mean(past_totals_cents)) <= SMALL_DIFFERENCE_CENTS

    def _within_normal_spread(self, past_totals_cents: list[int]) -> bool:
        return abs(self.total_cents - _mean(past_totals_cents)) <= 3 * _standard_deviation(past_totals_cents)

    def hold(self) -> None:
        self._record.status = "held"
        self._record.save()

    def finalize(self) -> None:
        self._record.status = "final"
        self._record.save()

    def unwrap(self) -> InvoiceRecord:
        return self._record


# How "history" and "spread" are measured: arithmetic, not policy.

def _too_little_history(past_totals_cents: list[int]) -> bool:
    return len(past_totals_cents) < INVOICES_NEEDED_FOR_A_HISTORY


def _mean(values: list[int]) -> float:
    return sum(values) / len(values)


def _standard_deviation(values: list[int]) -> float:
    # DECISION D1: the spread of all past invoices (population standard
    # deviation), not a sample estimate. See RULES.md.
    mean = _mean(values)
    return math.sqrt(sum((v - mean) ** 2 for v in values) / len(values))
