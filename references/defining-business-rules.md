# Defining the business rules

Getting the rules right is usually the hardest part of the work, and the part most often done badly. In most codebases a single business rule is split across a controller conditional, a model callback, a SQL scope, and a view, and nobody can say what the rule *is* without reading all four.

HexaDCI gives each rule one home. That only helps if someone first states the rule clearly. This file covers how to do that with a person (a new feature), how to do it from code (an existing system), and how to write it down so that the business and the code agree.

## Contents

1. Vocabulary: process, procedure, rule
2. Sorting statements
3. Workflow A: defining rules with a stakeholder (3a: rules that interact)
4. Writing rules well
5. The rule sheet (`RULES.md`)
6. From rule sheet to code
7. Workflow B: extracting rules from existing code
8. Workflow C: handling a change request
9. When no one can answer

---

## 1. Vocabulary: process, procedure, rule

These terms come from the original HexaDCI documentation.

- **Business process** — what the business does to accomplish something, as a sequence of steps and decisions, stated the way the business would state it. *"To register a merchant, the registration must be valid; if the deposit account is already on file, hold the registration; then tell the customer."* In code: the context's procedure comment and main method.
- **Business procedure** — the step-by-step instructions for carrying out one step: *"write these fields to the database," "process a payment through the gateway," "send the email."* In code: inside role methods and behind ports.
- **Business rule** — a decision, limit, calculation, eligibility condition, or timing that the business has chosen. *"Late fees are 1.5% of the balance, minimum $5."* In code: one role method or step, commented with the rule's ID.
- **Kind of participant** — a category of thing that is treated differently. *"Customers on a payment plan…," "accounts that came through a reseller…"* In code: a role variant chosen by the context's casting decision.
- **Fact** — data that is recorded, not decided: a due date, a balance, an email address. In code: the data object.
- **Outcome** — a distinct way the operation can end that someone cares about: *fee added, found paid, could not process.* In code: a listener method.

The process says *what and why*. Procedures say *how*. Programmers often merge them, writing "if status_id == 3, update the row and enqueue a mailer", and that merging is how rules get scattered across layers.

## 2. Sorting statements

Sort every sentence of a request, a ticket, a spec, or a piece of existing code into one of the kinds above. Two tests settle most cases:

- **The policy test:** *would this change if the business changed its mind?* Then it is a rule, a process step, or a participant kind.
- **The technology test:** *would this change if we changed vendors, databases, or frameworks?* Then it is a procedure.

| Statement | Kind | Home |
|---|---|---|
| "Check the bank before charging anyone" | Process step | Context main method |
| "1.5% of the balance, never less than $5" | Rule (calculation) | Role method, `# R3` |
| "More than 30 days past due" | Rule (eligibility) | Role method, `# R1` |
| "Customers on a payment plan never get late fees" | Participant kind + rule | Role variant + casting |
| "Tell the customer's billing contact" | Rule (who is told) | Role method calling a port |
| "Send it through SendGrid with template 42" | Procedure | Port implementation |
| "Save the fee" | Procedure | Inside the role method |
| "The due date" | Fact | Data object |
| "Ops wants a summary" | Outcome reporting | Listener |
| "When the player taps a slot, the pile goes there" | Interface wording around a rule | Restate as the intent — "the player chooses a slot; the pile goes to that slot and no other" — and put the tapping in the entry point |

When a sentence mixes kinds ("email the billing contact"), it usually splits into a rule (*who is told*) and a procedure (*by email*). Treat that as a question, not a verdict: the channel is itself a business requirement when a contract, a regulation, or a promise to customers says so ("notices must be sent by email with a receipt"). Ask "if we told them some other way, would anyone object?" If yes, the channel is a rule.

These categories are thinking aids. Use them to find the questions worth asking, not to file every sentence.

## 3. Workflow A: defining rules with a stakeholder

Use this for a new business operation, and whenever a request is vague or contradicts itself. **Scale it to the uncertainty:** a clear, authorized change needs one sentence of playback, not an interview.

### Run it as a conversation

1. **Name the operation** as a verb phrase the stakeholder would use ("assess late fees").
2. **Start with one ordinary case.** "Walk me through the last time you did this by hand." Real cases with real numbers expose rules people forget to state. Early on, also ask **what it is for**: "What goes wrong for the business if we don't do this, or do it badly?" The answer becomes the sheet's Purpose and is the yardstick for every later question.
3. **Play back the process you heard** in a few numbered steps, and ask the *next* question whose answer could change the outcome. One or two questions at a time, not a list.
4. **Keep a draft `RULES.md` and update it as you go.** Each answer adds or sharpens a rule, an outcome, or an example.
5. **Then go looking for trouble:** an edge case, a case that went wrong, and cases where several rules apply at once (section 3a).
6. **Resolve contradictions explicitly.** If two statements conflict ("stop the job if payroll is down… actually, paying half is fine"), quote both back and ask which one holds. Record the answer and who gave it.
7. **Confirm what is unresolved, not everything.** When you are ready to build, say "here are the two decisions that still affect the result" and ask about those. Do not make the stakeholder re-approve the whole sheet after every change; the sheet itself shows what was agreed.

### Questions to draw on

This is reference material for choosing the next question, not a script to read out. Each answer has a home in the code.

| Question | Reveals | Becomes |
|---|---|---|
| What is this for? What goes wrong without it? Why does this particular rule exist? | Purpose and reasons | `RULES.md` Purpose; each rule's "why"; rule doc comments |
| What starts this, and how often? Who else might start it? | Triggers and scopes | Entry points |
| How does it end? List every way. | Outcomes | Listener methods |
| What or who is involved? | Participants | Roles |
| Are some of them handled differently? "Except when…?" | Participant kinds | Role variants, casting decision |
| What gets decided at each step? On what basis? | Rules | Role methods and steps |
| Exactly where are the boundaries? (30 days: day 30 or 31? "Over $1M": the dollar at $1M?) | Boundary rules | Table-driven test rows |
| How are amounts rounded? Which time zone counts? | Hidden rules | Rule entries |
| What if something needed is missing, late, or unavailable? | Failure rules | Preconditions, record problems |
| Should one bad case stop everything, or just itself? | Isolation | Precondition gate vs per-record catch |
| What must never happen? | Invariants | Sanity checks |
| Who needs to know, and when? | Notifications, reports | Ports, listener |
| If this runs twice, what should happen? | Re-run safety | Idempotency rules |
| Who owns each rule, and who can change it? | Ownership | Rule sheet `Owner` field |
| Does the same record ever arrive twice? Can one external item (a deposit, a payment) apply to more than one thing? | Identity and allocation rules | Deduplication, allocation by external ID |
| If a follow-up (a notice, a sync) fails after the main change, what then? | Recovery rules | Retryable follow-up state, or a documented manual step |

### 3a. Rules that interact

Single rules are usually stated clearly; trouble lives where several apply at once. For each pair of participant kinds and each pair of rules that could both fire, ask what happens:

- **Kinds that overlap:** a reseller customer who is also on a payment plan. Which rule wins? Is there a priority, or are they independent?
- **One item, many targets:** one deposit whose memo names two invoices; one payment covering several months. Which one gets it, in what order?
- **Partial success:** the fee is saved but the notice fails; the payment succeeds but the download fails. Does the first part stand? Who recovers the second, and how?
- **Repetition:** the same invoice appears twice in a run; the job is re-run after a crash. What must not happen twice?
- **Ordering:** if rule A changes data rule B reads (adding a fee changes the balance a deposit must cover), which runs first?

Write each answer as a rule with an example row ("deposit names 2026-0412 and 2026-0413 → pays 0412 only"), so the interaction is tested, not just remembered.

## 4. Writing rules well

A well-written rule:

- **States one thing.** Split "overdue invoices over $100 get a fee unless the customer is on a plan" into an eligibility rule, a threshold rule, and a participant kind.
- **Says why.** "A pile can't go back onto its own column — *it would change nothing, yet cost the player a move*." The reason is what lets someone later judge whether the rule still serves its purpose, or whether a proposed change would break what it was for. If nobody can say why a rule exists, record that as a question (`Qn`): an unexplained rule is the knowledge this approach exists to preserve, already lost. A reason you worked out yourself is an inference: write it as one ("reason inferred: …") until the owner confirms it. Never supply a plausible reason in the owner's voice.
- **Uses the business's words**, not the schema's. "Suspended agents", not "`status = 'suspended'`".
- **Is independent of the interface.** No taps, clicks, screens, buttons, forms, requests, or rows: "the player chooses a slot", "the customer asks to cancel". The rule must stay true if the product becomes a desktop app, a CLI, or a batch job. When a stakeholder explains a rule through the screen they use, translate it to the intent and confirm the translation.
- **Has an ID** (`R1`, `R2`…) when it is worth tracing — it has an owner, a boundary, money attached, or someone will ask about it. Trivial conditions do not need one.
- **Says where it came from:** *stated* (the stakeholder said it), *inferred* (from an example, a document, or existing code — say which), or *proposed* (your suggestion, not yet agreed). Only stated rules, and inferred or proposed rules the owner has accepted, count as confirmed.
- **Has examples, including the boundaries.** "30 days past due → no fee; 31 → fee." Examples become test rows.
- **Says what happens when its inputs are missing.** "If the bank cannot be reached: charge nobody tonight."
- **Has an owner** (a role, not necessarily a person): Finance, Sales Ops, Compliance.
- **Is decisive.** Replace "usually," "should," and "as appropriate" with the actual condition, or record the vagueness as an open decision.
- **Has a source** when it comes from outside the business: a contract clause, a regulation, a card-network rule.

Rules that are often missing and worth asking about: rounding, time zones and the start and end of a day or month, ties and ordering, duplicates, one external item applying to several records, partial amounts, reversals and refunds, re-runs, follow-ups that fail, and what happens to records created before the rule existed.

## 5. The rule sheet (`RULES.md`)

Each feature folder has a `RULES.md` written for the business. It is the operation's specification, and the one document a stakeholder reviews.

```markdown
# <Operation name>

**Owner:** <team or role>   **Last confirmed:** <date> by <who>

## Purpose
<One or two sentences: what the business is trying to achieve with this operation,
and what would go wrong without it. This is the yardstick every rule below is judged against.>

## Trigger and scope
- <what starts it> — <scope>  (e.g. nightly — every open invoice)
- <other trigger> — <scope>   (e.g. Ops on request — one account)

## Participants
- **<participant>**: <kind A> | <kind B>   (how to tell them apart)

## Process
1. <step, in business words>
2. …
(The context's process comment repeats this list.)

## Rules
| ID | Rule | Examples | Source | Owner |
|----|------|----------|--------|-------|
| R1 | <one decisive statement> | <input → result>; <boundary → result> | stated / inferred from <what> / proposed | <owner> |

## Rules from elsewhere
- <qualified ID, e.g. "category_sight R1" or "play_move R19"> — <what it decides, in one line> — used at step <n>

## Outcomes
- <outcome>: <who is told, what they see>

## Must never happen
- N1 <invariant>  (checked by <sanity check>)

## Questions for the owner
- Q1 <a question only the business can answer; what the code does today> — <owner>

## Decisions awaiting confirmation
- D1 <a judgment call *you* made, and the alternative you rejected> — ask <owner>

## Not in scope
- <related things this operation deliberately does not do>
```

Keep it short. If a rule needs a paragraph, it is probably several rules. Leave out *Rules from elsewhere* unless the operation follows a rule owned by another sheet; then cite it there rather than restating it (`patterns.md` §16). Scale it too: a small operation's sheet may be ten lines. Sections with nothing to say can be left out.

**Source.** Mark each rule *stated*, *inferred from …*, or *proposed*, so that you and the owner can see at a glance what was said, what you concluded, and what still needs a yes. When the owner accepts an inferred or proposed rule, change its source to *stated* (or *confirmed by …*). **The source covers the reason too.** If the rule was stated but its reason is your inference, say so in the Source column ("stated; reason inferred"), and the code comment must say the same. A reader must always be able to tell what the owner decided from what an assistant concluded.

**Questions vs decisions.** A *question* (`Qn`) is something only the owner can answer, such as which of two conflicting behaviors is intended. A *decision* (`Dn`) is a judgment call you made in order to proceed, with the alternative you rejected; it also gets a `DECISION Dn:` comment in code. A read-only inventory usually has many questions and few decisions.

**Where the sheet lives.** Always in the operation's feature folder (`<package>/features/<operation>/RULES.md`), even before any feature code exists. A folder that holds only a rule sheet is the normal first state of a feature being extracted from legacy code; the code moves in later.

## 6. From rule sheet to code

| Rule sheet | Code |
|---|---|
| Operation name | Feature folder and context |
| Trigger and scope | Entry points (each loads its scope and picks a listener) |
| Participants and kinds | Role classes and the context's casting decision |
| Process | The context's process comment and main method, step for step |
| Rule `Rn` | One role method or rule function, with a doc comment explaining the rule in natural language, ending "(Business rule Rn.)" |
| Rule examples | Table-driven test rows |
| Outcomes | Listener methods |
| Must never `Nn` | Result object sanity checks |
| Decision `Dn` | `DECISION Dn:` comment at the rule it affects |

The point of the mapping is **ownership**: each rule has one home in the code. If `R3` is implemented in two places, the rule has been scattered again. IDs and tags are a tool for that, applied to the rules worth tracing; a small, obvious condition does not need an ID, but it still should not be repeated in several layers.

## 7. Workflow B: extracting rules from existing code

Use this when changing or refactoring a system whose rules are spread across layers, or when asked "what does this actually do?"

**Scale it to the change.** For a narrow, clearly requested change, inventory only the rules the change touches and the places they live (often a handful of rows), confirm nothing the user already settled, and make the change. Run the full workflow below when the user asks what the system does, when the change crosses several layers, or when money or customer-facing behavior is involved and the current rules are unclear.

1. **Pick one operation** and find every entry point that triggers it: routes, jobs, scheduled tasks, scripts, admin actions, webhooks, database triggers.
2. **Trace each path end to end** and collect every condition and calculation that touches business data. Look in all the places rules hide:
   - controller and handler conditionals, and parameter filtering;
   - model validations, callbacks or hooks, default values, and computed attributes;
   - query scopes, `WHERE` clauses, joins that silently exclude rows, and reporting SQL;
   - background jobs, schedules, retry settings, and cron timing;
   - database constraints, defaults, triggers, and views;
   - configuration flags, feature toggles, and environment-specific settings;
   - view and template conditionals (hidden buttons are often business rules);
   - front-end validation;
   - integration mappings (status-code translations often encode rules);
   - hard-coded IDs, magic numbers, and string comparisons.
3. **Write an inventory.** One row per rule, in business language:

| # | Rule as the code implements it | Kind | Where | Notes |
|---|---|---|---|---|
| 1 | Invoices more than 30 days past due get a fee | Eligibility | `InvoicesController#index` filter; `Invoice.overdue` scope | Controller uses `>= 30`, scope uses `> 30`: **conflict** |
| 2 | Accounts with `plan_id` set are skipped | Participant kind | `LateFeeJob#perform` | Meaning of `plan_id` unclear: **ask** |

   Translate technical conditions into business statements ("`status_id IN (3, 7)`" → "accounts that are suspended or closed"). Where the meaning is unclear, say so instead of guessing.
   Number inventory rows `I1`, `I2`… (not `R`): they describe what the code does *today*, which may not be what the business wants. Rows become rules (`R`) only after the owner confirms them.
4. **Flag** duplicates, conflicts between layers, rules that can never fire, rules that exist only in one entry path, and places where the layers *say* different things (a page that promises day 65 when the job acts on day 61). These are usually the bugs. Also check side effects that bypass the rule entirely: one path calling an integration and another not, a save hook that silently undoes a change, a trigger that fires for cases nobody intended.
5. **Pin current behavior with characterization tests** before moving anything: table-driven tests of what the system does today, including the conflicting cases, named after the inventory rows they cover.
   - Characterization tests are the exception to "business-logic tests need no database". When today's rules live in SQL, model hooks, or database triggers, the tests must run them, against an in-memory or disposable database. They are temporary: once the rule moves to its single home, its test becomes an ordinary rule test with fakes.
   - Rules that can only run in a template or the browser, where the project has no way to execute them in tests, are recorded in the inventory with their location and marked *not pinned by tests*. When the rule moves, the template stops deciding: the context or a view model computes the answer (`can_suspend`, `days_until_suspension`) and the template only displays it, so the rule becomes testable.
6. **Present the inventory as a draft `RULES.md`** (section 5): the inventory rows, a plain-language summary of where the rules disagree, today's outcomes, and every conflict and unknown listed as a question (`Qn`) for the owner, each stating today's behavior. Lead with the few questions that change the most. Where the user's request already settles a conflict, say so and do not ask again. Do not change the behavior in question until the conflicts that affect it are answered.
7. **After the owner answers,** rewrite the sheet as rules (`R1`…). The answers may differ from today's behavior; that is a rule change, made deliberately.
8. **Move one rule at a time** to its single home, turning its characterization tests into rule tests, until every rule appears in exactly one place.

## 8. Workflow C: handling a change request

1. Sort each sentence of the request (section 2).
2. Classify the change:
   - **Rule change**: update `RULES.md`, then change the one place the rule lives and its test rows. If the request states the new rule clearly, that is the confirmation; ask only about consequences the request did not cover (which interacting rules change, what happens to existing records).
   - **New participant kind**: add it to `RULES.md` participants, add a role variant and a casting branch.
   - **Procedure / implementation change** (new vendor, new email template, new data representation, new storage): no rule sheet change; change only implementation-level code. The rule tests must pass unchanged, and the commit should say it is an implementation change. If a rule test has to change, it was a rule change.
   - **New outcome or notification**: add a listener method or port, and a line under Outcomes.
3. If the request contradicts an existing rule, quote the existing rule and ask which one holds.

## 9. When no one can answer

When the stakeholder is unavailable or the request contradicts itself:

- Take the **most cautious reasonable reading**: the one that is easiest to undo and that does not charge, pay, notify, or delete on a guess.
- Record it as `Dn` under *Decisions awaiting confirmation* in `RULES.md`, with the alternative you did not choose.
- Put a `DECISION Dn:` comment at the rule it affects in code.
- List every open decision in your final report to the user.
