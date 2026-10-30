# Hex-DCI anti-patterns

## Drift seen in the original system

The original codebase evolved for several years before the architecture settled, so it contains earlier forms and lapses. Do not copy these.

| Drift | Why it hurts | Settled form |
|---|---|---|
| Raw SQL updates and console printing inside a context's main method | The procedure stops reading like the business, and output cannot be turned off | Move calculation into a step, persistence into a role, output into a listener |
| A role reaching into another role's private state to unwrap it | Couples roles to each other's internals | Call `unwrap()` or pass the data object explicitly |
| A generic delegator base class that forwards every method | Hides which data the operation actually depends on | Explicit wrappers that forward only what is used |
| Generic `traits/` and `habits/` directories shared across features for "reuse" | A grab bag named for the mechanism, not the concept: anything could be added, and nothing said whose rule it was | Share only what must agree by definition, in a folder named for the concept, with one owner and a qualified rule ID that each user cites (`patterns.md` §16) |
| Defaulting a listener to the null listener *class* instead of an instance | Calling a listener method fails at runtime | Default to an instance, consistently |
| Raising on one bad record and halting a whole batch | One surprise stops all other work | Collect warnings and failures; report to the listener |

## Too much structure

The opposite failure is just as real, and assistants following this skill are prone to it. The goal is clear ownership and readable interactions; more classes and paperwork do not add either.

- **A null-object class for every "do nothing".** Use a null role when a whole *kind* of participant skips a behavior. A one-off exception that a single conditional states clearly can stay a conditional in the role that owns the rule.
- **A step class for every few lines.** Extract a step when it makes the context easier to read, a part easier to test, or isolates a system boundary — not by line count.
- **Role variants for a single difference.** If two "kinds" differ in one line, they may not be kinds at all.
- **Rule IDs for everything.** IDs are for rules someone will look up, argue about, or change. Tagging trivial conditions turns the rule sheet into paperwork nobody reads.
- **Interviewing the user about a clear request.** "Add a $5 minimum" needs a one-line playback and the change. Ask only about decisions that would change the result.
- **Making the user re-approve the whole specification** after each change. Confirm what is unresolved.
- **Full legacy inventories for a narrow fix.** Inventory the rules your change touches.
- **Giving a pure calculation the effects machinery.** A rule engine over immutable values (game moves, pricing, eligibility) with a listener nobody implements, null objects, mutable working copies, and exceptions for "refused" ends up larger than the validator it replaced. Keep the roles that make it readable; drop the machinery that exists for effects (`patterns.md` §15).
- **A context file that holds more than the process.** Extensions, helpers, rule functions, and result types at the bottom of the context file bury the one thing it exists to show. Each goes in its own file in the feature folder; the context file is the process comment and the main method.
- **Rule annotations instead of rule explanations.** `// Business rule R4: …` lines scattered through the context, or terse tags above an `if`, explain nothing and clutter the process. Explain each rule in natural language in the doc comment of the role method that implements it, ending with its ID; let the context read as the process.
- **A mechanism the reader has to interpret.** `from == to`, `days > 30`, `status IN (3, 7)` inline in the context or a rule tells the reader *how*, and leaves them to work out *what* and *why*. That interpretation is institutional knowledge; when it lives only in people's heads, it leaves with them. Name the concept (`isOntoItself`, `more_than_30_days_past_due`, `suspended_or_closed`) even when the mechanism is one line.
- **Rules stated in interface terms.** "A tap always means what it pointed at", "the button is disabled when…", "the row is inserted". These describe one interface, not the business, and they tie the feature to it: move the logic to a desktop app or a batch job and the rule no longer makes sense. State the intent ("the player's choice of slot is honored exactly"), keep the tapping in the entry point, and keep UI and framework imports out of feature code.
- **Invented reasons in the owner's voice.** An assistant fills a missing "why" with a plausible guess and writes it as if the owner said it — in `RULES.md` or, worse, in a code comment with no Source column. It reads as a decision and will be trusted as one. Write inferred reasons as inferences ("reason inferred, not confirmed: …"), or leave the reason out and ask.
- **A rule with a name but no reason.** A well-named rule tells you what the system decides, not why the business wants it, so nobody can judge whether a proposed change would break its purpose. Put the reason in the rule's doc comment and in `RULES.md`; if no one knows it, record that as a question.
- **Treating good names as proof.** Names reduce inference; they don't verify anything. `isOntoItself` can be the wrong rule, or the right rule implemented wrongly. The point of naming is to make those two possibilities separately checkable: the rule against its purpose (by the owner), the mechanism against the rule (by tests).
- **Bug reports and reviews that don't say which kind of mistake.** "This is wrong" sends everyone back to reconstruct intent. Say whether the rule fails its purpose (a goal question, for the owner) or the code fails its rule (an implementation question, for the author).
- **"Done" when the output is right.** Code that produces correct results but leaves the next person to reconstruct what it is for and why is not finished by this skill's standard.
- **Tests and logs that say how, not what.** `test_due_for_late_fee_returns_true` and "fee added: 1500" make the investigator decode them. Name tests for the rule they check; log which rule decided, and from which facts.
- **A rule method that decodes the data to state its rule.** `isOntoItself => switch (this) { ColumnToColumn(:final from, :final to) => from == to, _ => false }` mixes the policy with how moves happen to be represented. Change the representation and the rule's code changes too, and the commit looks like a rule change. State the rule in business terms (`from == to`) and put the decoding beneath it.
- **Rule changes and implementation changes in one commit.** The history can no longer say when the policy changed. Commit them separately and say which kind each is; an "implementation" change that alters a rule test is a rule change.
- **A role method that could be a sentence, written as a condition.** `if (move is ColumnToColumn && move.from == move.to)` in the context makes the reader decode it. `if (move.isOntoItself)` says it; the role method holds the decoding and the explanation.
- **Over-correcting into an unreadable switch.** Removing roles from a pure operation whose input combines independent kinds (source × destination) produces a switch where every arm takes the request apart and re-wires the process with callbacks. That is harder to read than the roles were. Cast each axis into a pure role and write the process once.
- **A mutable shadow of the input.** A "role" that copies every field of the data object into its own lists, edits them, and rebuilds the object at the end is a second model, not a role. Wrap the data object, or compute a new immutable value from it.
- **A shared rule restated in each feature.** Two features each describe "what the player can see" in their own words and code; the next change updates one. Give it one home and have each feature's `RULES.md` cite its qualified ID under "Rules from elsewhere".
- **Sharing rules that only look alike.** Two features both use "30 days" today, so one shared constant serves both; then one owner changes theirs and the other changes silently. If one owner's change should not move the other, keep two rules.
- **A shared folder that imports a feature**, or a feature that imports another feature. Dependencies point from features to shared code, never back or sideways.
- **Moving shared vocabulary into a feature.** Types the rest of the app uses (moves, board state, accounts) stay in the shared models even when one feature uses them most. A sign of the mistake: another layer imports or re-exports them from the feature folder.
- **Exceptions as the normal path.** Throwing "refused" from deep inside and catching it in the context hides the control flow. Return refusals as values; keep exceptions for problems with the world (per-record failures in a batch, an unavailable service) and for bugs.
- **Player-facing wording inside the rules.** The feature decides what may be revealed or why something was refused; the UI decides the words.
- **A migration that grew.** If the migrated code is larger, with more moving parts, and no rule got clearer, it is not finished.
- **Classifying mechanically.** "Process vs procedure" is a thinking aid. Whether "by email" is a rule depends on whether the business requires email; ask.

## Mistakes AI assistants commonly make with this style

- **Putting the logic in the entry point.** Controllers, jobs, and CLI handlers gather inputs, call one context, and handle listener callbacks. No business decisions.
- **Adding methods to shared models.** If only one operation needs `in_bounds?`, it belongs on a role in that operation, not on the `Invoice` model.
- **Mutating objects to add roles** (monkey-patching, `extend` on instances, `Object.assign` onto records, prototype changes). Wrap instead.
- **Branching on type in steps** (`if account.reseller…` scattered through the procedure). Cast once in the context and let role methods differ.
- **Generic names.** `InvoiceService`, `process()`, `handle()`, `Manager`, `Helper`. Name the operation and its role methods in the business's words.
- **Returning the listener's result**, or making the context's return value depend on the listener.
- **Rendering, printing, or exiting from a context.** Report to the listener.
- **Calling infrastructure from the context or steps** (ORM, HTTP clients, mailers). Go through a role method or a port.
- **One giant context method.** If the main method no longer reads at a glance, extract steps.
- **Comment and code disagreeing.** The procedure comment is part of the contract; keep it current.
- **Premature shared abstractions** — a base `Context` class with hooks, a plugin registry, a generic pipeline framework — before there are several real features that need them. Conventions first.
- **A null default for a required effect.** If the rules say the customer must be told, a notifier that silently does nothing by default breaks a requirement while every test passes. Required ports have no default; previews and tests pass a fake explicitly.
- **A duplicate check that runs after the damage.** Validate or deduplicate input identities before any charge or message; keep the end-of-run check as a diagnostic only.
- **Tracking external items by object identity.** Two fetches of the same deposit are two objects. Track allocation by the external system's ID.
- **A warning as the only record of a failed follow-up.** A re-run skips records it already changed, so the notice is never sent. Give the follow-up its own state and retry it, or document manual recovery.
- **"Re-run it with the printing listener" as a debugging step for a real batch.** Visibility is not safety; the re-run charges and notifies again. Reproduce with isolated data and fake effect ports, or establish that replay is safe first.
- **A null object for a data source.** A "null bank" that returns no deposits, or a pricing port that defaults to zero, silently changes business outcomes. Only side-effect ports get null implementations; data sources raise when unavailable.
- **Catching everything per record.** A broad catch in a batch turns programming errors into "could not process" lines nobody reads. Catch the expected record-level errors; if you must catch broadly, report type and traceback and have something notice a rise in failures.
- **Interleaving an all-or-nothing check with changes.** If the run must stop when a source is down, gather everything first, then change records — never discover the outage halfway through charging.
- **Silently choosing between readings of an unclear rule.** Ask; if no one can be asked, take the cautious reading, record it as `Dn` in `RULES.md`, mark it `DECISION Dn:` in code, and list it in your summary.
- **Recording only the decisions that felt important.** In practice, the unrecorded ones are where the gaps hide (e.g. "a crash between the payment and the statement email means the statement is never sent"). Every judgment call goes in `RULES.md`.
- **Coding before the rules are stated.** Writing the context first and discovering the rules while debugging produces code shaped by the first guess. Draft `RULES.md` and play it back first.
- **Rules stated in schema terms.** "`status_id IN (3, 7)`" is not a rule; "suspended or closed accounts" is. If you cannot translate a condition into business words, ask what it means.
- **Merging rule and procedure in one sentence or one method.** "Email the billing contact" is two things: the rule (*who is told*) and the procedure (*by email*). Split them so each can change on its own.
- **The same rule in several places.** A condition repeated in a controller, a scope, and a job will drift. Each rule ID appears in exactly one place in production code.
- **Tests that need the database** for business rules. Use fakes; keep one thin wiring test per entry point.
- **Mocking everything with no business cases.** Tests should enumerate the business rules (table-driven), not restate the implementation line by line.
- **Splitting a feature across technical folders** (`services/`, `validators/`, `serializers/`) instead of keeping it in its own folder.
