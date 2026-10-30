# Assess late fees

**Owner:** Finance   **Last confirmed:** example — not a real confirmation

## Purpose
Encourage customers to pay on time, without ever penalizing someone who has already paid or has agreed a schedule with Finance. A wrong late fee costs more in trust and support calls than the fee is worth, so when in doubt the operation does not charge.

## Trigger and scope
- Nightly — every open invoice
- Ops, when a customer calls in — one account's open invoices

## Participants
- **Invoice**: chargeable | on a payment plan (the customer is on a payment plan)
- **Customer**: direct | came through a reseller

## Process
1. report any invoice whose account we cannot find, or that is listed more than once; carry on with the rest
2. send any late-fee notice from an earlier run that did not go out
3. pick the invoices due a late fee today
4. check the bank for every customer with such an invoice, before changing anything; if the bank is down, charge nobody tonight
5. for each due invoice: if a cleared deposit already covers it, mark it paid; otherwise add a late fee and tell whoever handles the customer's billing. One bad invoice does not stop the others
6. sanity-check the results and report the summary

## Rules
| ID | Rule | Step | Examples | Source | Owner |
|----|------|------|----------|--------|-------|
| R1 | An invoice is due a late fee when it is more than 30 days past due and its last late fee (if any) was at least 30 days ago — so a customer is never charged twice for the same month of lateness. | 3 | 30 days past due → no; 31 → yes; last fee 10 days ago → no; 30 days ago → yes | stated | Finance |
| R2 | Customers on a payment plan never get late fees, because they have already agreed a schedule with Finance. Their invoices are not checked at the bank either. | 3 | 90 days past due, on a plan → no fee | stated | Finance |
| R3 | A late fee is 1.5% of the balance, never less than $5.00, so small balances still carry a meaningful fee. Half a cent rounds up. | 5 | $1,000.00 → $15.00; $200.00 → $5.00; $501.00 → $7.52; $500.33 → $7.50 | stated (rounding inferred from the spreadsheet) | Finance |
| R4 | An invoice is already paid when a **cleared** bank transaction's memo names the invoice number as a whole word and the amount covers the balance. Each bank transaction pays one invoice only — even when two customers share a bank account and the bank reports the same transaction for both. | 5 | cleared $1,000 for a $1,000 balance → paid; $999.99 → fee; pending → fee; memo "2026-04120" for invoice 2026-0412 → fee; one $1,000 transaction naming 0412 and 0413 → pays 0412 only | stated | Finance |
| R5 | If the bank cannot be reached, no invoice is charged or marked paid that night: without the bank we cannot tell who has already paid. | 4 | bank down → nothing changes; summary says so | stated | Finance |
| R6 | When a fee is added, the customer's billing contact is told — unless the customer came through a reseller, in which case only the reseller is told, because the reseller owns that relationship. | 5 | direct → company billing email; reseller → reseller's email | stated | Finance |
| R7 | A problem with one invoice does not stop the others. An unreadable bank deposit stops that customer's invoices only. A failed notice is reported, and the fee stands. | 5 | one customer's deposit unreadable → that invoice listed, others charged | stated | Ops |
| R8 | An invoice listed more than once in a run is handled once; each repeat is reported and changes nothing. | 1 | invoice 0412 listed twice → one fee, one notice, one "listed more than once" line | proposed, accepted by Finance | Finance |
| R9 | A notice that did not go out is sent on the next run, and on every run after that until it does: a customer who is charged must hear about it. | 2 | notice fails tonight → fee stands, warning; tomorrow → notice sent | proposed, accepted by Finance | Finance |

## Outcomes
- **Late fee added** (amount); the right person is told (R6).
- **Found already paid**: the invoice is marked paid (R4).
- **Could not process** (reason): listed in the summary for Ops, including invoices listed twice (R8).
- **Notice failed**: listed as a warning; the fee stands and the notice is retried next run (R7, R9).
- **Earlier notice sent**: a notice from an earlier run finally went out (R9).
- **Bank unavailable**: one prominent line in the summary (R5).
- **Summary for Ops**: number of fees and total, number found paid, every problem with its reason.

## Must never happen
- N1 Change any invoice while the bank is unavailable.
- N2 Add a late fee below $5.00.
- N3 Charge, or mark paid, the same invoice twice in one run. (Prevented by R8 before anything changes.)

N1–N3 are also checked at the end of the run by `check_totals`, which stops loudly. That check is a diagnostic, not the guard: the guards are R5 and R8, which act before any change.

## Decisions awaiting confirmation
- D1 A late fee is added to the invoice's balance, so later fees are calculated on it and a deposit must cover it before the invoice counts as paid. Alternative: track fees separately from the balance. — ask Finance

## Not in scope
- Posting payments to invoices (only the status is changed here).
- Waiving fees, and payment-plan enrollment.
- Deposits older than the bank's 10-day window.
