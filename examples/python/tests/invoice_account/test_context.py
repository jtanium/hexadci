import unittest
from datetime import date

from features import invoice_account
from records import InvoiceRecord
from tests.fakes import FakeNotifier, RecordingListener, account, charge

STEADY_HISTORY = [10_000, 10_000, 10_000]


class InvoiceAccountContextTest(unittest.TestCase):
    def setUp(self):
        self.listener = RecordingListener()
        self.notifier = FakeNotifier()

    def invoice(self, acct, charges):
        return invoice_account.Context.call(account=acct, charges=charges, notifier=self.notifier,
                                            on=date(2026, 10, 1), listener=self.listener)

    def test_nothing_to_invoice_without_charges(self):
        acct = account()

        self.assertIsNone(self.invoice(acct, []))
        self.assertEqual([("nothing_to_invoice", acct)], self.listener.events)
        self.assertEqual([], self.notifier.sent)

    def test_in_bounds_invoice_is_finalized_and_the_account_notified(self):
        result = self.invoice(account(company_email="co@example.test", past_invoice_totals_cents=STEADY_HISTORY),
                              [charge(10_200)])

        self.assertEqual("final", result.status)
        self.assertEqual([("invoice_finalized", result)], self.listener.events)
        self.assertEqual(1, len(self.notifier.sent))

    def test_reseller_billed_account_is_finalized_but_not_notified(self):
        result = self.invoice(account(billed_through_reseller=True, past_invoice_totals_cents=STEADY_HISTORY),
                              [charge(10_200)])

        self.assertEqual("final", result.status)
        self.assertEqual([("invoice_finalized", result)], self.listener.events)
        self.assertEqual([], self.notifier.sent)

    def test_out_of_bounds_invoice_is_held_and_nobody_is_notified(self):
        result = self.invoice(account(company_email="co@example.test", past_invoice_totals_cents=STEADY_HISTORY),
                              [charge(25_000)])

        self.assertEqual("held", result.status)
        self.assertEqual([("invoice_held", result)], self.listener.events)
        self.assertEqual([], self.notifier.sent)

    def test_returns_the_invoice_record_not_the_listener_result(self):
        result = self.invoice(account(company_email="co@example.test"), [charge(1_000)])
        self.assertIsInstance(result, InvoiceRecord)

    def test_works_with_the_default_null_listener(self):
        result = invoice_account.Context.call(account=account(company_email="co@example.test"),
                                              charges=[charge(1_000)], notifier=self.notifier)
        self.assertEqual("final", result.status)
