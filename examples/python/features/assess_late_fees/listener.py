from typing import Protocol


class Listener(Protocol):
    """The outcomes of a late-fee run."""

    def invoice_not_processed(self, number: str, reason: str) -> None: ...
    def late_fee_added(self, invoice, fee_cents: int) -> None: ...
    def invoice_found_paid(self, invoice) -> None: ...
    def late_fee_notice_failed(self, invoice, reason: str) -> None: ...
    def earlier_notice_sent(self, invoice, fee_cents: int) -> None: ...
    def bank_unavailable(self, reason: str) -> None: ...
    def run_finished(self, run) -> None: ...


class NullListener:
    def invoice_not_processed(self, number, reason): pass
    def late_fee_added(self, invoice, fee_cents): pass
    def invoice_found_paid(self, invoice): pass
    def late_fee_notice_failed(self, invoice, reason): pass
    def earlier_notice_sent(self, invoice, fee_cents): pass
    def bank_unavailable(self, reason): pass
    def run_finished(self, run): pass


class SummaryListener(NullListener):
    """Nightly: only the summary Ops asked for."""

    def run_finished(self, run):
        if run.bank_unavailable:
            print(f"BANK UNAVAILABLE ({run.bank_unavailable}): no late fees were charged tonight")
        print(f"Late fees added: {len(run.late_fees)}, total {_dollars(run.late_fee_total_cents)}")
        print(f"Invoices found already paid: {len(run.found_paid)}")
        if run.earlier_notices_sent:
            print(f"Notices from earlier runs sent: {len(run.earlier_notices_sent)}")
        for number, reason in run.not_processed + run.warnings:
            print(f"  {number}: {reason}")


class PrintingListener(SummaryListener):
    """Single customer at the command line: narrate everything."""

    def invoice_not_processed(self, number, reason):
        print(f"Could not process {number}: {reason}")

    def late_fee_added(self, invoice, fee_cents):
        print(f"Added {_dollars(fee_cents)} late fee to {invoice.number}")

    def invoice_found_paid(self, invoice):
        print(f"{invoice.number} was already paid at the bank; marked paid")

    def late_fee_notice_failed(self, invoice, reason):
        print(f"Late fee on {invoice.number} stands, but the notice failed: {reason}")

    def earlier_notice_sent(self, invoice, fee_cents):
        print(f"Sent the notice for the earlier {_dollars(fee_cents)} late fee on {invoice.number}")

    def bank_unavailable(self, reason):
        print(f"Bank unavailable ({reason}); charging nobody")


def _dollars(cents: int) -> str:
    return f"${cents / 100:.2f}"
