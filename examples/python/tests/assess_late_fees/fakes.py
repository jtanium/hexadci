from datetime import date, timedelta

from features.assess_late_fees import NoticeFailed, NullListener
from ports.bank import BankUnavailable
from records import Account, InvoiceRecord, LateFee

TODAY = date(2026, 10, 29)


class FakeBank:
    """Answers with the bank's own record format. Never a null object: tests say
    exactly what the bank returns, or that it is down."""

    def __init__(self, deposits=None, *, down=False):
        self._deposits = deposits or {}
        self._down = down
        self.asked_about = []

    def recent_deposits(self, bank_account_number):
        self.asked_about.append(bank_account_number)
        if self._down:
            raise BankUnavailable("bank is down")
        return self._deposits.get(bank_account_number, [])


class FakeNotice:
    def __init__(self, *, failing=False):
        self.failing = failing
        self.sent = []

    def late_fee_added(self, *, to, invoice, fee_cents):
        if self.failing:
            raise NoticeFailed("mail server refused")
        self.sent.append({"to": to, "number": invoice.number, "fee_cents": fee_cents})


class RecordingListener(NullListener):
    def __init__(self):
        self.events = []

    def invoice_not_processed(self, number, reason):
        self.events.append(("invoice_not_processed", number, reason))

    def late_fee_added(self, invoice, fee_cents):
        self.events.append(("late_fee_added", invoice, fee_cents))

    def invoice_found_paid(self, invoice):
        self.events.append(("invoice_found_paid", invoice))

    def late_fee_notice_failed(self, invoice, reason):
        self.events.append(("late_fee_notice_failed", invoice, reason))

    def earlier_notice_sent(self, invoice, fee_cents):
        self.events.append(("earlier_notice_sent", invoice, fee_cents))

    def bank_unavailable(self, reason):
        self.events.append(("bank_unavailable", reason))

    def run_finished(self, run):
        self.events.append(("run_finished", run))

    def names(self):
        return [event[0] for event in self.events]


def account(id=1, **overrides) -> Account:
    return Account(**{"id": id, "name": f"Account {id}", "company_email": f"ap{id}@example.test",
                      "bank_account_number": f"acct-{id}", **overrides})


def invoice(number="2026-0412", account_id=1, days_past_due=45, balance_cents=100_000,
            last_fee_days_ago=None) -> InvoiceRecord:
    record = InvoiceRecord(account_id=account_id, number=number, due_date=TODAY - timedelta(days=days_past_due),
                           balance_cents=balance_cents, status="open")
    if last_fee_days_ago is not None:
        record.late_fees.append(LateFee(amount_cents=500, assessed_on=TODAY - timedelta(days=last_fee_days_ago),
                                        notice_sent=True))
    return record


def deposit(amt="1000.00", memo="INV 2026-0412", sts="CLR", txn_id="T-1") -> dict:
    return {"txn_id": txn_id, "amt": amt, "memo_txt": memo, "posted": "20261027", "sts": sts}
