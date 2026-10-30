"""Entry point (driving adapter): Ops runs late fees for one account when a
customer calls in. Same context and rules as the nightly job; narrower scope and
a listener that narrates every step.

Run from examples/python:  python -m bin.assess_late_fees_for_account ACCOUNT_ID
"""
import sys

from bin import demo_data
from features import assess_late_fees

account_id = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else None
account = next((a for a in demo_data.ACCOUNTS if a.id == account_id), None)
if account is None:
    sys.exit(f"No account {sys.argv[1:]!r}")

run = assess_late_fees.Context.call(
    invoices=[i for i in demo_data.open_invoices() if i.account_id == account.id],
    accounts=[account], bank=demo_data.Bank(), notice=assess_late_fees.StdoutLateFeeNotice(),
    on=demo_data.TODAY, listener=assess_late_fees.PrintingListener())

sys.exit(2 if run.bank_unavailable else 0)
