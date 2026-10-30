---
name: hexadci
description: Define business rules clearly and organize business logic as HexaDCI features — a rule sheet per business operation, one folder per operation, a Context that reads like the business process — casting records into feature-local roles with listeners and ports at the edges when the operation has effects, or a lean pure function returning result values when it doesn't — and table-driven tests. Use when adding or changing business behavior (billing, payouts, onboarding, approvals, reconciliation, notifications, reports with rules); when turning a stakeholder's request into precise rules; when asked what existing code actually does or to untangle rules scattered across controllers, models, jobs, and SQL; when a model or service class is accumulating unrelated methods; or when the user mentions HexaDCI, DCI, contexts and roles, use cases, business rules, or hexagonal/ports-and-adapters. Works in any object-oriented language; reference examples in Ruby, Python, TypeScript, and Dart/Flutter.
---

# HexaDCI

HexaDCI combines **DCI** (Data, Context, Interaction) with **hexagonal architecture** (ports and adapters). It makes the *business operation* the unit of code organization.

It was developed by Jason Edwards in a production Ruby billing and CRM system (2015–2020) and used by a team of developers. Its goal is code that a person can read as the business process it implements, change in one place, test without infrastructure, and debug one feature at a time.

## Why this exists: don't make the next person reverse-engineer the system

Systems preserve their mechanisms far more reliably than the reasoning behind them. `ColumnToColumn(:final from, :final to) => from == to` tells you *how* something is computed. It does not tell you that the comparison means *"the pile would go back where it came from"*, that this matters because a move that changes nothing should not cost the player a move, or what would break if it changed. Recovering that from the mechanism is reverse-engineering, and the knowledge it requires usually lives only in someone's head. When they leave, it leaves.

HexaDCI makes that knowledge part of the code's structure, in four layers that are kept **distinguishable**, so each can be checked against the others:

| Layer | Question it answers | Where it lives |
|---|---|---|
| **Purpose** | *Why* does the business want this? | `RULES.md` — the operation's purpose, and each rule's reason |
| **Rule** (the concept) | *What* is the system deciding? | Named role methods and constants: `isOntoItself`, `due_for_late_fee`, `DAYS_BETWEEN_FEES` |
| **Mechanism** | *How* is it computed from the data? | Implementation-level code beneath the rule |
| **Evidence** | *Does* the mechanism deliver the rule, and the rule the purpose? | Rule tests, decision logs, diagnostics |

In practice:

- **Label every "how" with its "what".** Any mechanism whose meaning a reader would have to infer gets a name that states the concept — even a one-line comparison. `isOntoItself` turns a comparison into a domain concept someone can discuss, test, and question.
- **Record the "why" next to the "what".** The rule's doc comment and its line in `RULES.md` say why the business wants it. A name says what; only a stated purpose lets someone judge whether the rule still makes sense.
- **Make it testable and observable in the same words.** Tests are named for the rules they check; decision logs say which rule decided what, from which facts. See `references/testing-and-troubleshooting.md`.

**The payoff: you can tell which kind of mistake was made.** When code is wrong, the author either misunderstood **the goal** — what the code was supposed to achieve — or misunderstood **how to implement** that goal. With only the mechanism (`from == to`), those two mistakes look identical: the intent was never written down, so you cannot say whether a bug is the right idea implemented badly or the wrong idea implemented faithfully. Once the intent is named and stated (`isOntoItself`, with its reason), the question splits in two, and each half can be answered on its own:

1. **Is the rule right?** Does "onto itself" — and refusing it — serve the stated purpose? This is a question about the goal. The business owner answers it, against `RULES.md`. A wrong answer is a **rule change**.
2. **Does the mechanism implement the rule?** Does `from == to` correctly decide "onto itself" for every kind of move? This is a question about implementation. An engineer answers it, and rule tests check it. A wrong answer is an **implementation fix**.

Different owners, different fixes, different commits. Without the split, every bug sends someone back to reconstruct the original author's intent before they can even classify it.

Be precise about the claim. Names *reduce* inference; they do not eliminate the need to know the domain, and naming a rule does not make it — or its implementation — correct. What naming does is make each of those two judgments *possible to make separately*, and the second one checkable by a test instead of by an expert.

**This is a different standard of done.** Code is not finished when it produces the right output. It is finished when someone unfamiliar with its history — a new developer, a reviewer, an AI assistant — can tell what it is for, why, and whether it does it, without reconstructing the original author's thinking. Apply that standard to code you write and to code you review.

(Related traditions pursue parts of this: domain-driven design's *ubiquitous language* — one vocabulary shared by the business and the code — and *design by contract*, which makes intended behavior explicit and checkable.)

## What matters, and how much of it to use

Two principles carry the day-to-day work:

1. **Clear ownership.** Every business rule has one obvious home, so changing it means changing one place.
2. **Readable interactions.** The code for an operation reads like the business process, so a person can check it against what the business said.

Everything else in this skill — roles, null objects, steps, rule IDs, listeners — is a means to these ends and to the one above. **Choose the smallest implementation that keeps ownership clear and the interaction readable.** A small conditional inside a role is fine when it is the clearest way to state a rule. An extra class, file, or ID that nobody will look for is cost, not structure. When a pattern below would add more ceremony than clarity, say so and use the simpler form.

## Two kinds of operation

Decide which kind you have before choosing any structure.

- **A business operation with effects** — it reads and changes records, calls other systems, tells people things, or runs as a batch (invoicing, late fees, payouts, purchases). It uses the full shape below: context, roles wrapping records, a listener, ports, per-record isolation.
- **A pure operation** — a calculation or judgment over values it is given, returning a result and touching nothing else (game rules, pricing a cart, checking eligibility, validating a form, computing a schedule). It still gets a context that reads like the process, and roles where participants come in kinds — but the roles are **pure**: they hold immutable values and return results or new values. Every outcome, refusals included, is a returned value. **No listener, no ports, no exceptions for ordinary outcomes, no mutable copies of the input.** See `references/patterns.md` §15.

**Readability is the test in both kinds.** The context's main method should read almost like the process in English: "take the pile from the source; place it at the destination." If it instead takes inputs apart and wires them together arm by arm (a `switch` whose every case restates the process with callbacks), cast the kinds into roles so the process is written once.

Many features are a pure operation wrapped by a thin effectful one (judge the move, then save it and update the screen). Keep the pure part pure and the effects at the edge.

## Process, procedure, rule

These distinctions are thinking aids. Use them to ask better questions, not to classify mechanically.

- A **business process** is what the business does and decides, step by step, in its own words: *"check the bank before charging anyone; if a deposit covers the invoice, mark it paid; otherwise add a late fee and tell the customer."* It changes when **policy** changes. It lives in the context.
- A **business procedure** is how one step is carried out: *"write the fee row," "send the email through the mail provider."* It changes when **technology** changes. It lives inside role methods and behind ports.
- A **business rule** is a decision, limit, or calculation the business chose: *"1.5% of the balance, minimum $5."* It has one owner in code: a role method, a step, or a clearly marked line in the context.

The line between rule and procedure is sometimes the question itself. "Tell the customer" is a rule and "by email" usually a procedure — unless the business requires email (a contract, a regulation, a customer promise). Ask rather than assume.

### Rules are portable: state them without the interface

Business rules are abstract ideas about the domain. They must not mention how anyone interacts with the system — no taps, clicks, screens, buttons, swipes, forms, routes, requests, rows, or JSON. The player *chooses* a reserve slot; they don't *tap* it. The customer *asks to cancel*; they don't *click Cancel*. The invoice *is recorded*; a row is not *inserted*.

This is what makes a feature **portable**: the same rules, context, and roles serve a phone app, a desktop app, a CLI, a batch job, or an API, because nothing in them depends on how the request arrived. The interface is an entry point; it translates a tap or a click into a domain request ("move this pile to reserve slot 2") and calls the context.

Two checks:

- **The rewording test.** Would the rule still be true, word for word, if the app became a voice app, a keyboard-only desktop app, or a nightly batch? If not, it has absorbed the interface. "A tap always means what it pointed at" fails; "the player's choice of slot is honored exactly — we never substitute another" passes.
- **The dependency test.** Feature code (context, roles, rule functions, results) imports no UI, web, or persistence framework — no Flutter widgets, no HTTP request types, no ORM. If it has to, something belongs at the edge.

Stakeholders often describe rules through the interface they know ("when I tap the slot…"). Translate to the intent behind it ("so the player chooses a slot…") and confirm the translation with them; do not copy the interface words into the rule.

### Keep them in different code, so changes stay apart

Rules and implementation details change for different reasons, at different times, by different people's say-so. Put them in different code so that **each kind of change touches only its own code**:

- **Process** — the context: the order of steps. Changes when the business changes how it works.
- **Rules** — role methods and rule functions written in **business terms only**: `isOntoItself => from == to`, `due_for_late_fee? => more_than_30_days_past_due? && no_fee_in_the_last_30_days?`. They ask other business-level questions and give business-level commands. They change when policy changes.
- **Implementation details** — how those questions are answered from the actual data and systems: decoding a representation (`switch` over move types to find where a move starts), field names, date arithmetic, persistence, APIs, formats. They live in lower-level role methods, on the shared data type when the whole app wants them, or behind ports. They change when technology or representation changes.

The payoff is in maintenance and in history:

- **A rule change** touches `RULES.md`, the rule method, and its test rows — and implementation code only if the rule needs new facts.
- **An implementation change** (a new data representation, file system → object database, a new mail provider) touches only implementation code. `RULES.md`, the rule methods, and the rule tests do not change, and the rule tests passing unchanged is the proof the rules did not change.
- **Commits stay aligned.** Keep rule changes and implementation changes in separate commits, and say which kind each is. A diff that touches both a rule method and storage code is two changes. If a supposedly implementation-only change forces a rule test or `RULES.md` to change, it is a rule change: stop and treat it as one.

A rule method that has to decode the data to state its rule is a sign the two are mixed: pull the decoding down into an implementation-level method, so the rule reads as the policy.

Rules worth tracing are written in the feature's `RULES.md`. Scattered rules — the same condition in a controller, a model callback, and a SQL scope — are the main thing this architecture exists to prevent. See `references/defining-business-rules.md`.

## The shape

```
entry point ──▶ Context ──▶ roles + steps ──▶ ports
(controller,     (one per     (feature-local     (listener, notifier,
 job, CLI,        business     wrappers and       gateway, clock…)
 script)          operation)   small callables)
```

- **Entry point** (driving adapter): a controller action, background job, CLI command, or script. It gathers inputs, calls one context, and does nothing else.
- **Context**: the single entry into one business operation. It *casts* each participant into the role it plays in this operation, runs the steps in business order, and returns an explicit result (reporting outcomes to a listener as well, when a caller needs one).
- **Role**: a small class, local to the feature, that wraps a data object and adds only the behavior this operation needs, named in business vocabulary. It never modifies the data object's class.
- **Step**: a small callable inside the feature folder for one part of the process (retrieve, price, build, calculate), used when it makes the context easier to read or the part easier to test.
- **Port** (driven adapter): an injected collaborator for anything outside the business logic: the listener for outcomes, notifiers, payment gateways, external APIs, clocks. **Choose each port's default from business policy:**
  - Optional effects (a diagnostic listener, narration) default to a null implementation.
  - Required effects (telling the customer when the rules say the customer must be told) have **no** default; callers must pass a real one, and tests pass a fake explicitly.
  - Sources whose *answers* drive decisions (a bank, a pricing service) never have a null version; an empty answer would silently change outcomes, so they fail loudly.
- **Data objects** (models, records, DTOs): hold data and broadly useful accessors. They do not accumulate operation-specific behavior.

## Core rules

1. **One folder per business operation**, named as a verb phrase for what the business does: `invoice_account/`, `assess_processing_fees/`, `close_merchant_account/`. What *only this operation* uses lives there: its context, roles, steps, rule sheet, feature-specific ports and errors. Types the rest of the app also uses — the domain's vocabulary (moves, board state, invoices, accounts) — stay in the shared models, even when this feature is their main user. If another folder would have to import it from the feature, it does not belong in the feature. Tests mirror the folder. A *rule* that several features — or a feature and the UI — must apply identically gets one shared home named for its concept (`rules/category_sight/`), one owner, and a qualified ID that each user cites rather than restates (`references/patterns.md` §16).
2. **The context's main method reads like the business process, and the context file holds nothing else.** Someone from the business should be able to follow it: `if (move.isOntoItself) return refused`, `invoice.hold_for_review unless invoice.in_bounds?`, `source.take(...)`, `destination.place(...)`. Put the process comment above it (from `RULES.md`), then code that matches it. Role methods, rule functions, result types, and helpers live in their own files in the feature folder; rule explanations live with the rules (rule 13), not in the context.
3. **Cast roles once, in the context,** when participants really come in kinds (`ResellerBilledAccount` vs `DirectBilledAccount`): decide in one place, by wrapping each in the right role class, and downstream code calls role methods without re-checking the kind. When an input combines several independent kinds (where a move comes from × where it goes), cast **each axis** into its own role; enumerating the combinations in a `switch` forces every arm to restate the process. Branching on an *outcome* (payroll accepted vs rejected) is normal control flow. A single local difference does not need its own role; a clear conditional in the owning role is fine.
4. **Roles give data objects operation-specific behavior, visible only inside the feature.** That is what lets the context read as sentences about domain things. Name role methods as business sentences: `isOntoItself`, `hold!`, `in_bounds?`, `belongs_to_distributor?`, `incur_processing_fees!`. Two ways to build a role:
   - **A scoped extension**, in languages that have them (Dart `extension`, Kotlin extension functions, C# extension methods): role methods declared in a feature file, on the shared data type, visible only where the feature imports them. Use this when the role adds behavior and holds no state of its own. It is the closest thing to DCI's original "inject the role into the object for this context."
   - **A wrapper class**, which holds the data object (and anything else the role needs), when the role holds extra state, when participants come in kinds that behave differently (sealed role classes chosen by casting), or in languages without scoped extensions. Provide `unwrap()` when the data object must be handed back at the edge.

   Either way, a role never **copies** the data object's fields into a parallel model, and never changes the shared class itself (no monkey-patching, no global mixins). If the data is immutable, role methods compute and return new values.
5. **Return an explicit result; add a listener only when something listens.** Contexts never render, redirect, print, or exit. Every outcome — including "refused" — is part of the returned result, as a value. Add a listener protocol when callers need to react to outcomes as they happen (a controller rendering, a batch narrating, a job summarizing); then default it to a null object and return the result yourself, never whatever the listener returned. Do not add one that nothing implements.
6. **The feature decides facts; the UI decides words.** A rule like "don't reveal category names on hard difficulty" belongs in the feature — it decides *what* may be revealed and returns that as data (a reason code, which names are visible). The wording of messages belongs to the presentation layer.
7. **Prefer a null role when a whole kind of participant skips a behavior** ("resellers are never notified" → `ResellerBilledAccount#notify_of_invoice!` does nothing, with a comment why). Its value is that the rule is owned by the kind it applies to. If there is no such kind and a one-line conditional says it clearly, use the conditional.
8. **Rule-level code is written in business terms; implementation details sit beneath it.** A rule method reads as the policy (`isOntoItself => from == to`) and calls lower-level methods for how the data answers (`from`, `to`), which may live on the shared data type, in an implementation-level role method, or behind a port. Ask "would this change if the policy changed, or if the technology or representation changed?" before placing code. See "Keep them in different code" above.
9. **Each external system gets a boundary translator** — one place that converts the external system's language (field names, codes, formats, identifiers) into the feature's language. Keep the external system's stable identifiers (transaction IDs, product IDs) through translation; the business often needs them.
10. **Entry points stay thin.** Several entry points may call the same context. If two entry points need the same logic, it belongs in the context.
11. **Test each step and the context with fakes.** Participants are fakes or doubles that respond to role messages; ports are fakes that record calls. Business-logic tests need no database, network, or framework. (Exception: characterization tests that pin legacy behavior living in SQL or triggers, until those rules move.) Make tests table-driven over business cases so they read as the rulebook, and include the cases where rules interact. Name tests and test builders in business terms ("an invoice 31 days late owes a fee", `invoice(days_past_due: 31)`), so a failing test says *what* broke.
12. **Make diagnostics part of the feature.** Report surprising data at the point of surprise with full context, and keep going if the business allows it. For batches, see `references/patterns.md` §12: reject or deduplicate repeated inputs and check run-wide preconditions *before* changing anything, isolate per-record failures without hiding programming errors, give follow-up effects (notices) their own retryable state, and keep end-of-run sanity checks as diagnostics, not as the guard.
13. **Each rule has one owner in code, and its explanation lives there, in natural language.** The role method or rule function that implements a rule carries a doc comment that explains it the way the business would: what the rule is, why it exists, the edge case people ask about, and who decided it — ending with its ID, e.g. *"(Business rule R4; decided in D3.)"*. Write it in domain terms, never interface terms (see "Rules are portable"). Give only reasons the owner stated; if a reason is your inference, either leave it out or mark it plainly — *"Reason inferred, not confirmed: …"* — matching `RULES.md`. The context does not repeat rule explanations; its process comment says *what happens*, and the role methods it calls say *why*. A rule that *is* the process — an ordering or a gate, like "check the bank before changing anything" — is stated by the process comment, and if its code needs a word of explanation, a short natural sentence at that step is enough. Rules that someone will look up, argue about, or change get an ID in `RULES.md` (`R1`…) and test rows from their examples; trivial conditions do not need IDs. A business condition repeated in several places is the thing to fix, with or without an ID.

    ```dart
    /// A pile can't be moved back onto the column it came from. Nothing on the
    /// board would change, yet the old game counted it as a move, which cost the
    /// player a move for nothing — so it is refused instead.
    /// (Business rule R4; decided in D3.)
    bool get isOntoItself => from == to; // `from` and `to` are implementation-level: they decode the move
    ```
14. **Abstract only after two concrete cases.** Until then, keep the concrete code and label the shortcut honestly where it lives (`# ABSTRACTION_NEEDED: …`).

## Workflow: defining the business rules

Scale this to the uncertainty. A clear, authorized request ("add a $5 minimum to the late fee") needs a sentence of playback and the change, not an interview. A vague request, a contradiction, money, or code nobody understands needs more. Details, questions, and the template are in `references/defining-business-rules.md`.

1. **Have a conversation, not a questionnaire.** Start with one ordinary case: "Walk me through the last time this happened." Play back the process as you understand it, then ask the *next* question whose answer could change the outcome. Keep a draft and update it as you learn.
2. **Probe boundaries and interactions.** Exact thresholds (day 30 or 31?), rounding, missing information, partial failures, repeated runs — and what happens when several rules apply at once (a reseller customer on a payment plan; one deposit naming two invoices; a notice failing after the fee is saved). Interactions expose missing priorities and ordering.
3. **Track where each rule — and each reason — came from.** In `RULES.md`, mark each rule *stated* (the user said it), *inferred* (from an example or the code), or *proposed* (your suggestion), so you can say plainly "you specified this; I inferred that from your example; this third point needs a decision." Do the same for **reasons**: a reason the owner gave is stated; a reason you worked out is inferred, and says so. **Never write an inferred reason in the owner's voice** — not in `RULES.md`, and not in a code comment, where there is no Source column to correct it. An invented reason that reads like a decision is worse than no reason: it is false institutional knowledge.
4. **Confirm what is unresolved, not everything.** Present only the decisions that would change the result ("two things affect the outcome: …"). Do not make the user re-approve the whole specification after each change. If the request is clear and the user has authorized the work, proceed and state your inferences.
5. **If no one can answer**, record each material judgment call as `Dn` in `RULES.md` with the alternative you rejected. Choose the reading whose mistakes are easiest to detect and correct; when money or messages could go wrong in either direction, avoid the irreversible external effect (a duplicate payment, a wrong charge) and say so. Mark each with a `DECISION Dn:` comment in code and list them in your final report.
6. **For existing code,** inventory the rules your change touches (rows `I1`…, in business words, with locations), across every layer where they could hide. For a narrow change that is a few rows; for "what does this system actually do?" it is the whole operation. Flag conflicts and paths that skip a side effect, pin current behavior with characterization tests where you will change it, and ask about conflicts (`Qn`) that the user's request does not already settle.

## Workflow: adding a business operation

1. **Name the operation** as a verb phrase the business would use. Create its folder and matching test folder.
2. **Start from the rules** — a `RULES.md` with no material decision left open. Copy its numbered process into the context's comment block.
3. **Write the context's main method** to match the comment, calling role methods and steps that do not exist yet. Prefer one line per business step.
4. **Identify the participants and their kinds.** Where kinds differ in behavior, decide the casting in the context constructor. Cast each participant on its own axis; when one participant's role depends on another's (an invoice and its customer), cast the related participant first and let the role hold it. Participants that cannot be cast (an invoice with no account) are set aside and reported as the first step of the process.
5. **Write the roles**, wrapping the data objects. Add only the methods the context and steps call.
6. **Extract a step** when it makes the context easier to read, the part easier to test, or isolates a system boundary.
7. **Define the result type** — one case per business outcome, refusals included. Add a listener protocol only if a caller needs to react to outcomes as they happen.
8. **Inject ports** only for real effects and outside systems, choosing each default from business policy (see Port above). A pure operation has none.
9. **Write the tests**: turn each rule's examples into test rows, add a test for each must-never invariant and for rule interactions, and cover each role variant.
10. **Wire the entry point**: gather inputs, call the context (with a listener, if it has one), act on the result, done. The entry point chooses the *scope* (all customers tonight, one customer on the phone); the context applies the *business selection* ("more than 30 days past due").

## Workflow: changing an existing operation

1. Find the operation's folder. Read its `RULES.md`, then the context's comment and main method.
2. Decide which kind of change it is, and say so:
   - **Process or rule change** — update `RULES.md`, settle anything unresolved, change the one rule method or the context, and update the rule's test rows.
   - **Implementation change** — change only implementation-level code (representation decoding, storage, APIs, formats). Do not touch `RULES.md`, rule methods, or rule tests; run the rule tests unchanged to show the rules still hold. If you find you must change a rule test, it is a rule change after all — stop and treat it as one.
3. If the change adds a kind of participant that behaves differently, add it to `RULES.md`, add a role and a casting branch rather than `if` checks scattered through steps.
4. Keep `RULES.md`, the process comment, and the code in agreement.
5. **Commit rule changes and implementation changes separately**, each with a message that says which kind it is, so the history shows when policy changed and when only the technology did.

## Workflow: migrating existing code into a feature

The goal of a migration is ownership — each rule in one place, conflicts resolved — not the shape of the examples.

1. Extract the rules (`RULES.md`, inventory scaled to the code) and settle the conflicts that matter.
2. Decide the kind of operation (pure or effectful) and keep whatever existing structure already gives each rule one clear home. A reasonably organized validator or service may only need its duplicated checks merged and its rules tagged.
3. Move into the feature folder only what only this operation uses. Shared domain types stay where the rest of the app imports them from.
4. Check the result against the original: it should be **no larger, with fewer places to look**. If the migrated code is bigger or has more moving parts and no rule became clearer, simplify before you finish, and say what you removed.

## Workflow: debugging

1. Start from the complaint in business words, then the entry point; it names the context.
2. Find the rule that decided: read the decision log for that record if there is one, otherwise read the context's process and locate the step where the outcome diverges.
3. **Compare the layers for that rule** — purpose, rule, mechanism, evidence. The mismatch says what kind of fix it is: mechanism ≠ rule is a bug; rule ≠ purpose is a question for the owner; tests missing the case means a missing row.
4. **Reproduce safely.** Turning on a printing or decision-logging listener adds visibility; it does not make a re-run safe — a real run can charge or notify again. Reproduce with isolated data and fake effect ports (a test, a copy of the data, a dry-run entry point), or re-run for real only when you have established the operation is safe to replay.
5. Write a failing test row built from the facts, named for the rule; then fix it in the one place that owns the rule, and commit it as the kind of change it was.

Details, decision logs, and the "before you say done" checklist: `references/testing-and-troubleshooting.md`.

## Choosing a structure for the change

| Situation | Do this |
|---|---|
| New business operation | New feature folder with a context |
| A calculation or judgment with no effects (game rules, pricing, eligibility) | Pure operation: a context returning a result value, pure roles for participants that come in kinds, rules tagged in the role or function that owns them (`references/patterns.md` §15) |
| A request combines independent kinds (source × destination, product × customer) | Cast each axis into a role; the context states the process once |
| Existing code is already reasonably organized | Merge duplicate rules into one home and tag them; do not add structure the code doesn't need |
| Same operation, new kind of participant that behaves differently | New role class + casting branch |
| One rule differs in one place, no real "kind" | A clear conditional in the role that owns the rule |
| Same operation, new data source | New contributor class (see `references/patterns.md`, "Contributors") |
| A whole kind of participant skips a behavior | Null role |
| Need to call an external system | Port + boundary translator that keeps the system's identifiers |
| Two operations (or an operation and the UI) use the same rule | Ask: if one owner changed it, must the other change too? If not, keep both concrete with their own IDs. If so, move it to a shared role named for the concept, with one owner; each user cites its qualified ID (`references/patterns.md` §16) |
| Several contexts begin with the same steps (authorization) | A small context of its own, called as one step of each process; no base-class hooks |
| A model is growing operation-specific methods | Move those methods into role classes in the operations that use them |
| Several entry points need the same operation at different scopes | One context; each entry point loads its scope and picks its listener |
| A batch could receive the same record twice | Reject or deduplicate by business identity before changing anything |
| A batch must stop entirely under some condition (a source is down) | Precondition gate before any change; see `references/patterns.md` §12 |
| A batch may be interrupted and re-run, or calls something that must not happen twice (payments) | Commit point per record, idempotency key in the boundary translator, resumable state; see `references/patterns.md` §12, "Re-runs" |
| A required follow-up (a notice) can fail after the main change | Give it its own state and retry it on the next run, or document manual recovery |
| Users want to see the result without effects (preview, dry run, quote) | A second entry on the same context or a read-only context, sharing the pure calculation steps; it gets no effect ports at all |
| Adding to an existing project | Put features at `<package>/features/<operation>/`; existing models are the data objects; ports used by several features go in `<package>/ports/`, a port only one feature uses lives in that feature's folder |

## When not to use this

- Plain CRUD with no business rules: use the framework's conventions directly.
- One-off scripts and spikes.
- Codebases with a different established architecture, unless the user asks to introduce HexaDCI. Then introduce it one operation at a time, starting with the operation that changes most often.

## Reference files

Read these when you need detail:

- `references/defining-business-rules.md` — the guided rules conversation, rule sources and status, interacting rules, the `RULES.md` template, extracting rules from existing code, change requests and unanswerable questions.
- `references/testing-and-troubleshooting.md` — kinds of tests and what each proves, tests that state the "what", decision logs (*why* the system decided) as values, the path from a complaint to a fix, and what to show before saying "done".
- `references/patterns.md` — each pattern with rationale and language-neutral sketches: casting, roles, listeners, null objects, contributors, boundary translators, batches and re-runs, diagnostics, tests, pure operations (§15), and sharing rules and sub-processes across features (§16).
- `references/anti-patterns.md` — what to avoid, including drift seen in the original system and mistakes AI assistants commonly make with this style (in both directions: too little structure and too much).
- `references/language-notes.md` — how roles, listeners, and null objects map to Ruby, Python, TypeScript, Dart/Flutter, Java/Kotlin, C#, and Go.
- `examples/ruby/`, `examples/python/`, `examples/typescript/`, `examples/dart/` — two complete features with tests, written the same way in each language, each with its `RULES.md`. In every one, rule methods read as policy with natural-language explanations, and the decoding sits beneath them; the Dart late-fee example puts those implementation-level facts in a named extension (`invoice_record_facts.dart`):
  - `invoice_account` — a single-record operation: role casting, a null-object role, a listener, an injected notifier.
  - `assess_late_fees` — a batch operation: two casting axes, a participant that cannot be cast, duplicate inputs rejected before any change, a bank port with no null version, a boundary translator that keeps bank transaction IDs, a precondition gate (bank down → charge nobody), narrow per-record catches, a required customer notice with retryable delivery state, a result object with sanity checks, a `DECISION:` comment, and two entry points at different scopes.
