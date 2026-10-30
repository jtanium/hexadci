# Testing and troubleshooting

Tests and logs are the **evidence** layer (see "Why this exists" in `SKILL.md`). They answer one question: *does the mechanism deliver the rule, and does the rule serve its purpose?* They should answer it in the same words as `RULES.md`, so that someone reading a failing test or a log line learns *what* went wrong, not just *where*.

## Contents

1. Kinds of tests and what each proves
2. Tests that state the "what"
3. Decision logs: recording *why* the system decided
4. Troubleshooting: from complaint to fix
5. Before you say "done"

---

## 1. Kinds of tests and what each proves

| Kind | Proves | Written in terms of | Changes when |
|---|---|---|---|
| **Rule tests** | Each rule decides correctly, including boundaries and interactions | Business inputs and outcomes: "an invoice 31 days late owes a fee" | A rule changes |
| **Must-never tests** | Invariants hold (`N1`…): nothing charged while the bank is down | Business situations | An invariant changes |
| **Implementation tests** (only where useful) | A mechanism works: memo parsing, rounding, a boundary translator | The mechanism's own inputs | The implementation changes |
| **Wrapper / wiring tests** | The effectful edge keeps its promises: a refused move leaves the board, the move count, and the undo history untouched; an entry point calls the right context | The caller's behavior | The wiring changes |
| **Characterization tests** (legacy only) | What the system does today, before rules move | Today's behavior, conflicts included | Temporary — replaced by rule tests |

The split matters for change management. **An implementation-only change must leave rule tests untouched and passing**; that is the proof that no policy changed. If an "implementation" change forces a rule test to change, it was a rule change.

## 2. Tests that state the "what"

A test is often the first thing a newcomer reads. Make it teach the rule.

- **Name tests after the rule they check, in business words.** "an invoice 31 days past due owes a fee", "a pile can't go back onto its own column", "a deposit naming two invoices pays only the first". Not `test_due_for_late_fee_returns_true`.
- **Build test data in business terms.** `invoice(days_past_due: 31)`, `account(on_payment_plan: true)`, `deposit(memo: "2026-0412 2026-0413")`, rather than raw dates and status codes the reader must decode. A test builder is a place to label the how with the what, just like a role method.
- **Turn each rule's examples into table rows.** The rows *are* the examples column of `RULES.md`; the table reads as the rulebook. Include the boundary on both sides (30 → no, 31 → yes).
- **Add rows for interacting rules** (`references/defining-business-rules.md` §3a): a reseller customer on a payment plan; one deposit naming two invoices; a notice failing after the fee is saved.
- **One test per must-never invariant**, written as the situation that would violate it.
- **Test rules through the rule-level methods,** not through the mechanism. Then the tests survive implementation changes.
- **Fakes speak the port's language.** `FakeBank` answers in the bank's own format; `FakeNotice` can be told to fail. Never a null object for a data source, even in tests — say exactly what the bank returns.

## 3. Decision logs: recording *why* the system decided

An outcome log says *what happened*: "Added $15.00 late fee to 2026-0412." A decision log says *why*: "R1 — 2026-0412 is due a late fee: 45 days past due, no fee in the last 30 days." When a customer complains, the decision log turns troubleshooting into reading the business story instead of stepping through code.

### Decisions as values

The cleanest way to get decision logs without teaching roles about logging: a rule method can return a small **decision value** — the outcome, the rule that decided, and the facts it used — instead of a bare boolean.

```
Decision(rule: "R1", outcome: true, reason: "due for a late fee",
         facts: { days_past_due: 45, days_since_last_fee: none })
```

```
# in the context
due = invoice.late_fee_decision(on)
listener.decided(invoice, due)          # a diagnostic listener; the default does nothing
if due.outcome: ...
```

- The role stays pure and testable: tests assert on the decision (outcome *and* facts).
- The context reports each decision to a listener. A decision-logging listener can be switched on **for one feature** — the per-feature logging the original Hex-DCI system had — without touching the rules.
- Use decision values for rules that matter when something goes wrong: money, eligibility, anything a customer might dispute. Simple rules can stay booleans; do not wrap every condition.
- A lighter alternative where a decision value is overkill: the context logs after the rule method returns, pulling the facts from role accessors.

### What a decision log must contain

- **The rule ID and the decision**, in the words of `RULES.md`.
- **The facts the rule used** — enough to rebuild the case as a test row. If you cannot write the failing test from the log line, the log is missing facts.
- **The record's business identity** (invoice number, account), never just an internal ID.
- **Nothing sensitive.** No card numbers, bank account numbers, passwords, or personal data beyond what Ops already sees; mask or omit them.

### Three kinds of output, kept apart

| Output | Audience | Default | Example |
|---|---|---|---|
| **Narration / summary** of outcomes | Ops, the person running a job | On for jobs and CLIs | "Late fees added: 2, total $20.00" |
| **Decision log** of why | Whoever investigates a complaint | Off; switch on per feature, or keep in production at low volume where disputes are common | "R4 — 2026-0415 found paid: cleared deposit T-1001 names it and covers $120.00" |
| **Diagnostics** for surprises | Engineering | Always on | "could not read deposit {…} for bank account ending 0111" |

## 4. Troubleshooting: from complaint to fix

1. **Start from the complaint in business words.** "I was charged a late fee but I'd already paid."
2. **Find the entry point and the run.** The entry point names the context.
3. **Read the decision log for that record**, or reproduce it to get one (step 5). Find the rule that decided: "R4 — not found paid: deposit T-2207 is pending."
4. **Compare the four layers** for that rule:
   - **Purpose** — what is the business trying to achieve? ("Don't charge customers who have paid.")
   - **Rule** — what does `RULES.md` say? ("Only a *cleared* deposit counts.")
   - **Mechanism** — does the code do what the rule says?
   - **Evidence** — do the rule's tests cover this case?

   This is the question the whole structure exists to answer: **did the author misunderstand the goal, or the implementation of the goal?**
   - **The mechanism disagrees with the rule** — the code does not do what the named rule says. The goal was understood; the implementation was not. An implementation fix: rule tests and `RULES.md` stay as they are, and a new test row exposes the bug.
   - **The rule disagrees with the purpose** — the code faithfully does what the rule says, but the rule does not achieve what the business wanted (the customer *had* paid, but the rule ignores pending deposits). The goal was misunderstood, or has changed. A question for the owner, then a rule change: `RULES.md`, the rule, and its tests change together.
   - **Both look right, and the tests miss the case** — add the row, and check which of the two it exposes.

   Without a named rule and a stated purpose, you cannot make this distinction: the mechanism is all there is, and every bug first requires reconstructing what the author meant.
5. **Reproduce safely.** Use isolated data and fake effect ports (a test, a copy of the data, a dry-run entry point). Turning on a printing or decision-logging listener adds visibility; it does not make re-running a real batch safe.
6. **Write the failing test first,** as a table row built from the logged facts, named for the rule.
7. **Fix it in the one place that owns the rule** — or, if it was a rule question, update `RULES.md` with the owner's answer first.
8. **Commit it as what it was:** a rule change or an implementation change.

## 5. Before you say "done"

An AI assistant (or a developer) has not finished a change until it can show the evidence:

- Which rules the change touched, by ID, and the tests that cover each — run, and passing.
- For an implementation-only change: the rule tests unchanged and passing.
- For a rule change: `RULES.md`, the rule method, its doc comment's *why*, and its test rows all updated together.
- New behavior that someone might dispute later: does it produce a decision someone can read?
- The reading test: could a newcomer tell what each changed line is *for*, and why, without reconstructing your thinking?
- No interface words in rules, rule comments, or feature code, and no UI or web framework imports in the feature folder.
- Every reason you wrote down is either one the owner gave, or marked as your inference.
- Every rule ID appears in exactly one place in production code — searched across the whole source tree, since a shared rule lives outside the feature folder — and every rule cited from another sheet is listed under "Rules from elsewhere". If you changed a shared rule, every feature that cites it was checked and its tests run.
- The review test: for each rule you touched, could a reviewer judge separately (1) whether the rule is right for its purpose, and (2) whether your code implements the rule? If those two judgments can only be made together, the intent is not yet explicit.

When **reviewing** someone else's code, ask the two questions separately and say which one each finding is about: "this rule doesn't serve its stated purpose" is for the owner; "this code doesn't implement its rule" is for the author.
