import re
from dataclasses import dataclass

from ports.bank import Bank

from .errors import UnrecognizedDeposit


@dataclass(frozen=True)
class Deposit:
    transaction_id: str  # the bank's ID: the same transaction always has the same ID
    amount_cents: int
    memo: str
    cleared: bool


_CLEARED = {"CLR": True, "PND": False}
_DOLLARS = re.compile(r"(\d+)(?:\.(\d{1,2}))?")


class RetrieveDeposits:
    """This step is the boundary between us and the bank's deposits API. Its only
    job is translation: the bank's field names and codes ("txn_id", "amt",
    "memo_txt", "sts") in, our Deposit out. It keeps the bank's transaction ID,
    because which transaction paid which invoice is a business question (R4).
    Whether a deposit counts as payment is decided by the invoice role, not here."""

    @classmethod
    def call(cls, *, bank: Bank, bank_account_number: str) -> list[Deposit]:
        return cls(bank=bank, bank_account_number=bank_account_number)()

    def __init__(self, *, bank, bank_account_number):
        self._bank = bank
        self._bank_account_number = bank_account_number

    def __call__(self) -> list[Deposit]:
        return [self._translate(raw) for raw in self._bank.recent_deposits(self._bank_account_number)]

    def _translate(self, raw: dict) -> Deposit:
        transaction_id = str(raw.get("txn_id") or "")
        amount = _DOLLARS.fullmatch(str(raw.get("amt", "")))
        if not transaction_id or not amount or raw.get("sts") not in _CLEARED:
            raise UnrecognizedDeposit(
                f"{type(self).__name__}._translate could not read deposit {raw!r} "
                f"for bank account ending {str(self._bank_account_number)[-4:]}")

        dollars, cents = amount.group(1), (amount.group(2) or "").ljust(2, "0")
        return Deposit(transaction_id=transaction_id,
                       amount_cents=int(dollars) * 100 + int(cents),
                       memo=str(raw.get("memo_txt") or ""),
                       cleared=_CLEARED[raw["sts"]])
