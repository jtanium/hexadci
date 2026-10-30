from collections import Counter
from dataclasses import dataclass, field

from .errors import ImpossibleRun
from .late_fee_invoices import MINIMUM_FEE_CENTS


@dataclass
class Run:
    """The result of one run: what Ops sees in the nightly summary."""

    late_fees: list[tuple[str, int]] = field(default_factory=list)      # (invoice number, fee cents)
    found_paid: list[str] = field(default_factory=list)                 # invoice numbers
    not_processed: list[tuple[str, str]] = field(default_factory=list)  # (invoice number, reason)
    warnings: list[tuple[str, str]] = field(default_factory=list)       # (invoice number, reason)
    earlier_notices_sent: list[str] = field(default_factory=list)       # invoice numbers (R9)
    bank_unavailable: str | None = None

    @property
    def late_fee_total_cents(self) -> int:
        return sum(cents for _number, cents in self.late_fees)

    def check_totals(self) -> None:
        """Impossible results (N1-N3 in RULES.md) mean something upstream is wrong; stop loudly.

        This is a diagnostic, not the guard: by the time it runs, changes have been
        made. The guards are the bank gate (R5) and duplicate rejection (R8), which
        act before anything changes."""
        if self.bank_unavailable and (self.late_fees or self.found_paid):
            raise ImpossibleRun("invoices were changed although the bank was unavailable")
        if any(cents < MINIMUM_FEE_CENTS for _number, cents in self.late_fees):
            raise ImpossibleRun(f"a late fee is below the minimum: {self.late_fees!r}")

        changed = [number for number, _ in self.late_fees] + self.found_paid
        duplicates = [number for number, count in Counter(changed).items() if count > 1]
        if duplicates:
            raise ImpossibleRun(f"invoices changed more than once: {duplicates!r}")
