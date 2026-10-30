import unittest

from features import assess_late_fees
from records import LateFee
from tests.assess_late_fees.fakes import (TODAY, FakeBank, FakeNotice, RecordingListener, account, deposit,
                                          invoice)

# (description, invoice attributes, account attributes, charged?)
WHO_IS_CHARGED = [
    ("more than 30 days past due",  dict(days_past_due=31),                         dict(),                      True),
    ("exactly 30 days past due",    dict(days_past_due=30),                         dict(),                      False),
    ("last fee only 10 days ago",   dict(days_past_due=90, last_fee_days_ago=10),   dict(),                      False),
    ("last fee 30 days ago",        dict(days_past_due=90, last_fee_days_ago=30),   dict(),                      True),
    ("customer on a payment plan",  dict(days_past_due=90),                         dict(on_payment_plan=True),  False),
]

# (description, deposits at the bank, found paid?)
BANK_CASES = [
    ("cleared deposit covering the balance",      [dict(amt="1000.00")],          True),
    ("cleared deposit over the balance",          [dict(amt="1500.00")],          True),
    ("cleared deposit short of the balance",      [dict(amt="999.99")],           False),
    ("pending deposit covering the balance",      [dict(sts="PND")],              False),
    ("deposit for another invoice",               [dict(memo="INV 2026-0999")],   False),
    ("memo with a longer number containing ours", [dict(memo="INV 2026-04120")],  False),
]


class AssessLateFeesContextTest(unittest.TestCase):
    def setUp(self):
        self.bank = FakeBank()
        self.notice = FakeNotice()
        self.listener = RecordingListener()

    def assess(self, invoices, accounts=None):
        return assess_late_fees.Context.call(invoices=invoices, accounts=accounts or [account()], bank=self.bank,
                                             notice=self.notice, on=TODAY, listener=self.listener)

    def test_who_is_charged(self):
        for description, invoice_attrs, account_attrs, charged in WHO_IS_CHARGED:
            with self.subTest(description):
                run = self.assess([invoice(**invoice_attrs)], [account(**account_attrs)])
                self.assertEqual(1 if charged else 0, len(run.late_fees))

    def test_bank_check_before_charging(self):
        for description, deposits, paid in BANK_CASES:
            with self.subTest(description):
                self.bank = FakeBank({"acct-1": [deposit(**attrs) for attrs in deposits]})
                record = invoice()
                run = self.assess([record])

                self.assertEqual(["2026-0412"] if paid else [], run.found_paid)
                self.assertEqual("paid" if paid else "open", record.status)
                self.assertEqual(0 if paid else 1, len(run.late_fees))

    def test_late_fee_is_added_and_the_billing_contact_told(self):
        record = invoice(balance_cents=100_000)
        run = self.assess([record])

        self.assertEqual([("2026-0412", 1_500)], run.late_fees)
        self.assertEqual(101_500, record.balance_cents)
        self.assertEqual([{"to": "ap1@example.test", "number": "2026-0412", "fee_cents": 1_500}], self.notice.sent)

    def test_reseller_is_told_instead_of_the_customer(self):
        self.assess([invoice()], [account(billed_through_reseller=True, reseller_email="billing@reseller.test")])
        self.assertEqual(["billing@reseller.test"], [n["to"] for n in self.notice.sent])

    def test_bank_down_means_nobody_is_charged_or_marked_paid(self):
        self.bank = FakeBank(down=True)
        records = [invoice(number="A-1"), invoice(number="B-2", account_id=2)]

        run = self.assess(records, [account(id=1), account(id=2)])

        self.assertEqual("bank is down", run.bank_unavailable)
        self.assertEqual([], run.late_fees)
        self.assertTrue(all(r.status == "open" and not r.late_fees for r in records))
        self.assertEqual([], self.notice.sent)
        self.assertEqual(["bank_unavailable", "run_finished"], self.listener.names())

    def test_payment_plan_customers_are_never_checked_at_the_bank(self):
        self.bank = FakeBank(down=True)
        run = self.assess([invoice(days_past_due=90)], [account(on_payment_plan=True)])

        self.assertEqual([], self.bank.asked_about)
        self.assertIsNone(run.bank_unavailable)

    def test_unreadable_deposit_stops_that_customer_only(self):
        self.bank = FakeBank({"acct-1": [deposit(amt="twelve")], "acct-2": []})
        run = self.assess([invoice(number="A-1"), invoice(number="B-2", account_id=2)], [account(id=1), account(id=2)])

        self.assertEqual(["A-1"], [number for number, _ in run.not_processed])
        self.assertIn("could not read deposit", run.not_processed[0][1])
        self.assertEqual(["B-2"], [number for number, _ in run.late_fees])

    def test_failed_notice_is_a_warning_and_the_fee_stands(self):
        self.notice = FakeNotice(failing=True)
        record = invoice()
        run = self.assess([record])

        self.assertEqual(1, len(record.late_fees))
        self.assertEqual(["2026-0412"], [number for number, _ in run.warnings])
        self.assertIn("late_fee_notice_failed", self.listener.names())

    def test_invoice_without_an_account_is_reported_and_the_rest_continue(self):
        run = self.assess([invoice(number="ORPHAN", account_id=99), invoice(number="A-1")])

        self.assertEqual([("ORPHAN", "no account 99")], run.not_processed)
        self.assertEqual(["A-1"], [number for number, _ in run.late_fees])

    def test_one_deposit_pays_one_invoice(self):
        self.bank = FakeBank({"acct-1": [deposit(memo="2026-0412 2026-0413")]})
        run = self.assess([invoice(number="2026-0412"), invoice(number="2026-0413")])

        self.assertEqual(["2026-0412"], run.found_paid)
        self.assertEqual(["2026-0413"], [number for number, _ in run.late_fees])

    def test_an_invoice_listed_twice_is_charged_and_notified_once(self):
        record = invoice(balance_cents=100_000)

        run = self.assess([record, record])

        self.assertEqual([("2026-0412", 1_500)], run.late_fees)
        self.assertEqual(101_500, record.balance_cents)
        self.assertEqual(1, len(self.notice.sent))
        self.assertEqual([("2026-0412", "listed more than once in this run")], run.not_processed)

    def test_one_transaction_pays_one_invoice_even_when_customers_share_a_bank_account(self):
        shared = "shared-acct"
        self.bank = FakeBank({shared: [deposit(memo="2026-0412 2026-0413", txn_id="T-77")]})
        records = [invoice(number="2026-0412", account_id=1), invoice(number="2026-0413", account_id=2)]

        run = self.assess(records, [account(id=1, bank_account_number=shared),
                                    account(id=2, bank_account_number=shared)])

        self.assertEqual(["2026-0412"], run.found_paid)
        self.assertEqual(["2026-0413"], [number for number, _ in run.late_fees])

    def test_a_failed_notice_is_sent_on_the_next_run(self):
        record = invoice()
        self.notice = FakeNotice(failing=True)
        first = self.assess([record])
        self.assertEqual(["2026-0412"], [number for number, _ in first.warnings])
        self.assertFalse(record.late_fees[0].notice_sent)

        self.notice.failing = False
        self.listener = RecordingListener()
        second = self.assess([record])

        self.assertEqual([], second.late_fees)  # not charged again: the last fee was today
        self.assertEqual(["2026-0412"], second.earlier_notices_sent)
        self.assertEqual([{"to": "ap1@example.test", "number": "2026-0412", "fee_cents": 1_500}], self.notice.sent)
        self.assertTrue(record.late_fees[0].notice_sent)
        self.assertIn("earlier_notice_sent", self.listener.names())

    def test_a_notice_that_keeps_failing_is_reported_again_each_run(self):
        record = invoice()
        self.notice = FakeNotice(failing=True)
        self.assess([record])

        second = self.assess([record])

        self.assertEqual(["2026-0412"], [number for number, _ in second.warnings])
        self.assertFalse(record.late_fees[0].notice_sent)

    def test_earlier_notices_go_out_even_when_the_bank_is_down(self):
        record = invoice()
        record.late_fees.append(LateFee(amount_cents=1_500, assessed_on=TODAY))  # notice never sent
        self.bank = FakeBank(down=True)

        run = self.assess([record])

        self.assertEqual(["2026-0412"], run.earlier_notices_sent)
        self.assertEqual([], run.late_fees)

    def test_programming_errors_are_not_hidden_as_record_problems(self):
        broken = invoice()
        broken.due_date = None  # a bug upstream, not bad customer data

        with self.assertRaises(Exception) as raised:
            self.assess([broken])
        self.assertNotIsInstance(raised.exception, assess_late_fees.RecordProblem)

    def test_returns_the_run_and_reports_it(self):
        run = self.assess([invoice()])

        self.assertIsInstance(run, assess_late_fees.Run)
        self.assertEqual(("run_finished", run), self.listener.events[-1])
