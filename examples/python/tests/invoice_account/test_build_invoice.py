import unittest
from datetime import date

from features.invoice_account.billable_accounts import BillableAccount
from features.invoice_account.build_invoice import BuildInvoice
from features.invoice_account.draft_invoice import DraftInvoice
from tests.fakes import account, charge


class BuildInvoiceTest(unittest.TestCase):
    def test_dates_addresses_and_adds_a_line_per_charge(self):
        acct = BillableAccount(account(company_email="co@example.test"))
        invoice = DraftInvoice.new_for(acct)
        on = date(2026, 10, 1)

        BuildInvoice.call(invoice=invoice, account=acct, on=on,
                          charges=[charge(2_995, "Monthly fee"), charge(7_310, "Processing")])

        record = invoice.unwrap()
        self.assertEqual(on, record.invoice_date)
        self.assertEqual(["co@example.test"], [r.email for r in record.recipients])
        self.assertEqual(["Monthly fee", "Processing"], [line["description"] for line in record.lines])
        self.assertEqual(10_305, record.total_cents)
