"""Port: the bank's deposits API.

A bank's `recent_deposits(bank_account_number)` returns the bank's own records, e.g.

    [{"txn_id": "T-88231", "amt": "125.50", "memo_txt": "INV 2026-0412", "posted": "20261027", "sts": "CLR"}]

"txn_id" is the bank's own identifier for the transaction. It stays the same
however many times, or for however many customers, the transaction is reported.

There is deliberately no NullBank. Its answers drive decisions: a bank that
answered "no deposits" would have us charge customers who already paid.
A bank that cannot answer raises BankUnavailable.
"""
from typing import Protocol


class BankUnavailable(Exception):
    pass


class Bank(Protocol):
    def recent_deposits(self, bank_account_number: str) -> list[dict]: ...
