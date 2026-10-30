import unittest

from features.invoice_account.draft_invoice import DraftInvoice
from records import InvoiceRecord


def invoice_totaling(cents: int) -> DraftInvoice:
    invoice = DraftInvoice(InvoiceRecord(account_id=1))
    invoice.add_line(description="Fee", amount_cents=cents)
    return invoice


# (description, past totals, this total, in bounds?)
IN_BOUNDS_RULES = [
    ("no history",                         [],                       1_000_000, True),
    ("fewer than three past invoices",     [1_000, 1_000],           1_000_000, True),
    ("within $5.00 of the average",        [10_000, 10_000, 10_000], 10_500,    True),
    ("just over $5.00 with no variation",  [10_000, 10_000, 10_000], 10_501,    False),
    ("within three standard deviations",   [10_000, 20_000, 30_000], 40_000,    True),
    ("beyond three standard deviations",   [10_000, 20_000, 30_000], 50_000,    False),
    ("far below the average counts too",   [10_000, 10_000, 10_000], 1_000,     False),
]


class DraftInvoiceTest(unittest.TestCase):
    def test_in_bounds_rules(self):
        for description, past, total, expected in IN_BOUNDS_RULES:
            with self.subTest(description):
                self.assertEqual(expected, invoice_totaling(total).in_bounds(past))

    def test_add_line_accumulates_the_total(self):
        invoice = invoice_totaling(1_000)
        invoice.add_line(description="Another fee", amount_cents=250)
        self.assertEqual(1_250, invoice.total_cents)
        self.assertEqual(2, len(invoice.unwrap().lines))

    def test_hold_marks_held_and_saves(self):
        invoice = invoice_totaling(1_000)
        invoice.hold()
        self.assertEqual("held", invoice.unwrap().status)
        self.assertTrue(invoice.unwrap().saved)

    def test_finalize_marks_final_and_saves(self):
        invoice = invoice_totaling(1_000)
        invoice.finalize()
        self.assertEqual("final", invoice.unwrap().status)
        self.assertTrue(invoice.unwrap().saved)
