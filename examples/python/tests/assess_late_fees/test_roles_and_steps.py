import unittest

from features.assess_late_fees import ImpossibleRun, Run, UnrecognizedDeposit
from features.assess_late_fees.late_fee_invoices import ChargeableInvoice, PaymentPlanInvoice
from features.assess_late_fees.retrieve_deposits import RetrieveDeposits
from tests.assess_late_fees.fakes import TODAY, FakeBank, deposit, invoice

# (description, balance cents, fee cents)
FEE_RULES = [
    ("1.5% of the balance",            100_000, 1_500),
    ("never less than $5.00",           20_000,   500),
    ("half a cent rounds up",           50_100,   752),
    ("under half a cent rounds down",   50_033,   750),
]


class LateFeeCalculationTest(unittest.TestCase):
    def test_late_fee_amounts(self):
        for description, balance, fee in FEE_RULES:
            with self.subTest(description):
                role = ChargeableInvoice(invoice(balance_cents=balance), customer=None)
                self.assertEqual(fee, role.late_fee_cents)

    def test_payment_plan_invoices_are_never_due(self):
        role = PaymentPlanInvoice(invoice(days_past_due=365), customer=None)
        self.assertFalse(role.due_for_late_fee(TODAY))


class RetrieveDepositsTest(unittest.TestCase):
    def deposits(self, *raw):
        return RetrieveDeposits.call(bank=FakeBank({"acct-1": list(raw)}), bank_account_number="acct-1")

    def test_translates_the_banks_fields_into_ours(self):
        translated = self.deposits(deposit(amt="125.5", memo="INV 7", sts="PND"))[0]

        self.assertEqual(12_550, translated.amount_cents)
        self.assertEqual("INV 7", translated.memo)
        self.assertFalse(translated.cleared)

    def test_whole_dollar_amounts(self):
        self.assertEqual(12_500, self.deposits(deposit(amt="125"))[0].amount_cents)

    def test_keeps_the_banks_transaction_id(self):
        self.assertEqual("T-42", self.deposits(deposit(txn_id="T-42"))[0].transaction_id)

    def test_refuses_what_it_cannot_read(self):
        for raw in [deposit(amt="12.345"), deposit(amt="-5.00"), deposit(sts="XYZ"), deposit(txn_id="")]:
            with self.subTest(raw=raw):
                with self.assertRaises(UnrecognizedDeposit):
                    self.deposits(raw)


class RunTest(unittest.TestCase):
    def test_impossible_runs_raise(self):
        cases = {
            "changed while the bank was down": Run(bank_unavailable="down", late_fees=[("A-1", 1_500)]),
            "fee below the minimum": Run(late_fees=[("A-1", 100)]),
            "invoice changed twice": Run(late_fees=[("A-1", 1_500)], found_paid=["A-1"]),
        }
        for description, run in cases.items():
            with self.subTest(description):
                with self.assertRaises(ImpossibleRun):
                    run.check_totals()

    def test_a_reported_repeat_is_not_an_impossible_run(self):
        Run(late_fees=[("A-1", 1_500)], not_processed=[("A-1", "listed more than once in this run")]).check_totals()
