from records import Account, Charge, Contact


class RecordingListener:
    """Records every message it receives, so tests can assert on outcomes."""

    def __init__(self):
        self.events = []

    def nothing_to_invoice(self, account):
        self.events.append(("nothing_to_invoice", account))
        return "listener return value should be ignored"

    def invoice_finalized(self, invoice):
        self.events.append(("invoice_finalized", invoice))
        return "listener return value should be ignored"

    def invoice_held(self, invoice):
        self.events.append(("invoice_held", invoice))
        return "listener return value should be ignored"


class FakeNotifier:
    def __init__(self):
        self.sent = []

    def invoice_ready(self, *, recipients, invoice):
        self.sent.append({"recipients": recipients, "invoice": invoice})


def account(**overrides) -> Account:
    return Account(**{"id": 7, "name": "Example Coffee", **overrides})


def contact(name: str) -> Contact:
    return Contact(name=name, email=f"{name.lower()}@example.test")


def charge(amount_cents: int, description: str = "Fee") -> Charge:
    return Charge(description=description, amount_cents=amount_cents)
