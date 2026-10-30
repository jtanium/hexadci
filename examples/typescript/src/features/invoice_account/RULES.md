# Invoice an account

**Owner:** Billing   **Last confirmed:** example — not a real confirmation

## Purpose
Bill each account accurately for what it used, without surprising anyone: an invoice that is far out of line with an account's history is usually a mistake upstream, and sending it would cost trust and support time. So unusual invoices wait for a person, and ordinary ones go straight out.

## Trigger and scope
- Monthly billing run — one account at a time, with its uninvoiced charges for the period
- Other operations that need an immediate invoice (e.g. a signup fee) — one account, the charges they pass in

## Participants
- **Account**: direct-billed | reseller-billed (the account came to us through a reseller who bills it)
- **Invoice**: the draft being prepared

## Process
1. if the account has no uninvoiced charges, there is nothing to do
2. build a draft invoice from the charges
3. if its total is far out of line with past invoices, hold it for review
4. otherwise finalize it and notify the account

## Rules
| ID | Rule | Step | Examples | Source | Owner |
|----|------|------|----------|--------|-------|
| R1 | An account with no uninvoiced charges gets no invoice — an empty invoice only confuses the customer. | 1 | 0 charges → no invoice | stated | Billing |
| R2 | An invoice is dated the day it is built, has one line per charge, and totals the charges, so the customer can check every line against what they used. | 2 | $29.95 + $73.10 → total $103.05 | stated | Billing |
| R3 | Invoices go to the account's billing contacts; if there are none, to the company email; if there is no company email, to every contact. | 2 | billing contact Pat → Pat only; none, company email set → company email; neither → all contacts | stated | Billing |
| R4 | An invoice is out of line when the account has at least three past invoices and its total is more than $5.00 from their average **and** more than three standard deviations from it. Such invoices are usually upstream mistakes; small differences never are. | 3 | no history → in line; past $100, $100, $100: $105.00 → in line, $105.01 → out; past $100, $200, $300: $400 → in line, $500 → out | inferred from the old billing code (see D1) | Billing |
| R5 | An out-of-line invoice is held for review and nobody is told about it, so a mistaken invoice never reaches the customer. | 3 | $250 against steady $100 history → held, no notice | stated | Billing |
| R6 | Reseller-billed accounts are never contacted about invoices; the reseller owns that relationship and sends its own. | 4 | reseller-billed, in line → finalized, no notice | stated | Billing |

## Outcomes
- **Nothing to invoice**: no invoice; the caller is told.
- **Finalized**: the invoice is saved as final; the account is notified (R3) unless reseller-billed (R6).
- **Held for review**: the invoice is saved as held (R5).

## Must never happen
- N1 Notify anyone about a held invoice. (Context test: "out-of-bounds invoice is held and nobody is notified")

## Decisions awaiting confirmation
- D1 R4 uses the spread of *all* past invoices (population standard deviation), not a sample estimate. The difference matters only for accounts with few invoices. — ask Billing

## Not in scope
- Reviewing and releasing held invoices.
- Collecting payment.
