"""Stand-ins for persistence-backed models (an ORM, a repository, etc.).

They hold data and broadly useful accessors, and nothing specific to any one
business operation. Operation-specific behavior lives in role classes inside
each feature package.
"""
from dataclasses import dataclass, field
from datetime import date


@dataclass
class Contact:
    name: str
    email: str


@dataclass
class Charge:
    description: str
    amount_cents: int


@dataclass
class Account:
    id: int
    name: str
    company_email: str | None = None
    billing_contacts: list[Contact] = field(default_factory=list)
    contacts: list[Contact] = field(default_factory=list)
    billed_through_reseller: bool = False
    reseller_email: str | None = None
    on_payment_plan: bool = False
    bank_account_number: str | None = None
    past_invoice_totals_cents: list[int] = field(default_factory=list)


@dataclass
class LateFee:
    amount_cents: int
    assessed_on: date
    notice_sent: bool = False


@dataclass
class InvoiceRecord:
    account_id: int
    number: str | None = None
    invoice_date: object = None
    due_date: date | None = None
    recipients: list[Contact] = field(default_factory=list)
    lines: list[dict] = field(default_factory=list)
    total_cents: int = 0
    balance_cents: int = 0
    late_fees: list[LateFee] = field(default_factory=list)
    status: str = "draft"
    saved: bool = False

    def save(self) -> None:
        self.saved = True
