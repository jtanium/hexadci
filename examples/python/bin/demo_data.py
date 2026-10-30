"""Demo data standing in for the database and the bank, so the entry points run."""
from datetime import date, timedelta

from records import Account, InvoiceRecord

TODAY = date(2026, 10, 29)

ACCOUNTS = [
    Account(id=1, name="Example Coffee", company_email="ap@coffee.test", bank_account_number="000111"),
    Account(id=2, name="Resold Bakery", billed_through_reseller=True, reseller_email="billing@reseller.test",
            bank_account_number="000222"),
    Account(id=3, name="Planned Books", on_payment_plan=True, bank_account_number="000333"),
]


def open_invoices() -> list[InvoiceRecord]:
    def days_ago(n):
        return TODAY - timedelta(days=n)

    return [InvoiceRecord(account_id=1, number="2026-0412", due_date=days_ago(45), balance_cents=100_000, status="open"),
            InvoiceRecord(account_id=1, number="2026-0415", due_date=days_ago(40), balance_cents=12_000, status="open"),
            InvoiceRecord(account_id=2, number="2026-0420", due_date=days_ago(35), balance_cents=20_000, status="open"),
            InvoiceRecord(account_id=3, number="2026-0431", due_date=days_ago(90), balance_cents=50_000, status="open")]


class Bank:
    DEPOSITS = {
        "000111": [{"txn_id": "T-1001", "amt": "120.00", "memo_txt": "INV 2026-0415 thanks", "posted": "20261027", "sts": "CLR"}],
    }

    def recent_deposits(self, bank_account_number):
        return self.DEPOSITS.get(bank_account_number, [])
