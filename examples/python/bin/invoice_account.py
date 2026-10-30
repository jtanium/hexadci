"""Entry point (driving adapter): a CLI.

It gathers inputs, calls the context, and lets the listener decide what the
outcome means here. A web handler would implement the listener methods itself
and render in them instead.

Run from examples/python:  python -m bin.invoice_account
"""
from features import invoice_account
from ports import StdoutNotifier
from records import Account, Charge

account = Account(id=42, name="Example Coffee", company_email="billing@example.test",
                  past_invoice_totals_cents=[10_000, 10_500, 9_800])
charges = [Charge(description="Monthly gateway fee", amount_cents=2_995),
           Charge(description="Processing fees", amount_cents=7_310)]

invoice_account.Context.call(account=account, charges=charges,
                             notifier=StdoutNotifier(),
                             listener=invoice_account.PrintingListener())
