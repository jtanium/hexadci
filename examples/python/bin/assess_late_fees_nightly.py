"""Entry point (driving adapter): the nightly job.

Scope: every open invoice. In a real app these would come from the database.
Prints only the summary.

Run from examples/python:  python -m bin.assess_late_fees_nightly
"""
import sys

from bin import demo_data
from features import assess_late_fees

run = assess_late_fees.Context.call(invoices=demo_data.open_invoices(), accounts=demo_data.ACCOUNTS,
                                    bank=demo_data.Bank(), notice=assess_late_fees.StdoutLateFeeNotice(),
                                    on=demo_data.TODAY, listener=assess_late_fees.SummaryListener())

sys.exit(2 if run.bank_unavailable else 0)
