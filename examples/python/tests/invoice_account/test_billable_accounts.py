import unittest

from features.invoice_account.billable_accounts import (
    BillableAccount, DirectBilledAccount, ResellerBilledAccount)
from features.invoice_account.draft_invoice import DraftInvoice
from records import InvoiceRecord
from tests.fakes import FakeNotifier, account, contact


def recipients_for(acct):
    return BillableAccount(acct).recipients()


class BillableAccountsTest(unittest.TestCase):
    def test_recipients_are_billing_contacts_when_present(self):
        billing = [contact("Pat")]
        acct = account(billing_contacts=billing, company_email="co@example.test", contacts=[contact("Sam")])
        self.assertEqual(billing, recipients_for(acct))

    def test_recipients_fall_back_to_company_email(self):
        acct = account(company_email="co@example.test", contacts=[contact("Sam")])
        self.assertEqual(["co@example.test"], [r.email for r in recipients_for(acct)])

    def test_recipients_fall_back_to_all_contacts(self):
        everyone = [contact("Sam"), contact("Lee")]
        self.assertEqual(everyone, recipients_for(account(contacts=everyone)))

    def test_direct_billed_account_notifies_its_recipients(self):
        notifier = FakeNotifier()
        role = DirectBilledAccount(account(company_email="co@example.test"), notifier=notifier)
        invoice = DraftInvoice(InvoiceRecord(account_id=7))

        role.notify_of_invoice(invoice)

        self.assertEqual(1, len(notifier.sent))
        self.assertEqual(["co@example.test"], [r.email for r in notifier.sent[0]["recipients"]])
        self.assertIs(invoice.unwrap(), notifier.sent[0]["invoice"])

    def test_reseller_billed_account_is_never_notified(self):
        role = ResellerBilledAccount(account(company_email="co@example.test"))
        self.assertIsNone(role.notify_of_invoice(DraftInvoice(InvoiceRecord(account_id=7))))
