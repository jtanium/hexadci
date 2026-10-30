## Architecture: Hex-DCI

Business logic in this project is organized by business operation, not by technical layer.

- **Rules come first.** Each operation's folder has a `RULES.md`: trigger and scope, participants and their kinds, the numbered business process, rules with IDs (`R1`…) and boundary examples, outcomes, must-never invariants, and decisions awaiting confirmation. Draft or update it — and play it back to the user in business words — before writing or changing code.
- **Process vs procedure.** A *process* step or *rule* changes when policy changes and lives in the context, a role, or a step, in exactly one place, with a natural-language doc comment ending "(Business rule Rn.)". A *procedure* ("save the row", "send the email") changes when technology changes and lives inside role methods or behind ports. Split sentences that mix the two.
- **Existing code:** before changing an operation whose rules are scattered, inventory every condition on business data across all layers, translate each into business words, flag conflicts, and confirm with the owner.

- **One folder per business operation**, named as a verb phrase (`invoice_account/`, `close_merchant_account/`). Everything that exists only for that operation lives there; tests mirror it.
- **Each operation has a Context** with one entry point (`Context.call(...)`). Its main method reads like the business procedure, under a comment that states the procedure as numbered steps. Keep comment and code in agreement.
- **The Context casts participants into roles once**, in its constructor (e.g. `ResellerBilledAccount` vs `DirectBilledAccount`). Downstream code calls role methods and never branches on type.
- **Roles are feature-local** scoped extensions (Dart, Kotlin, C#) or wrapper classes around data objects, with methods named in business language (`hold`, `in_bounds`, `notify_of_invoice`). Do not add operation-specific methods to shared models, and never mutate objects to add behavior.
- **A rule several features (or a feature and the UI) must apply identically** gets one shared home named for its concept (`rules/<concept>/`), one owner, and a qualified ID each user cites under "Rules from elsewhere" in its `RULES.md`. Share only rules that must agree by definition, not ones that merely look alike today. Features never import from other features.
- **Contexts report outcomes to a listener** (one method per outcome, a null listener by default) and return an explicit value. They never render, print, or exit. Controllers pass themselves as the listener; CLIs pass a printing listener.
- **Side effects go through injected ports** (notifier, gateway, clock). Give a port a null implementation only when doing nothing is safe (listeners, notifiers); ports whose answers drive decisions (a bank, a pricing service) must raise when unavailable. "Do nothing in this case" is a null role or null port with a comment, not an `if`.
- **Batches** check run-wide preconditions before changing anything, isolate per-record failures with narrow catches, and return a result object with sanity checks.
- **When a rule is unclear** and no one can be asked, take the reading whose mistakes are easiest to detect and correct (avoid irreversible external effects such as duplicate payments), record it as `Dn` in `RULES.md`, mark it `DECISION Dn:` in code, and list every decision in your summary.
- **Re-runnable batches** record a commit point per record before any external call, derive idempotency keys from the business identity of the effect, and treat a timeout as "unconfirmed", not "failed".
- **Each external system gets one boundary-translator step** that converts its field names and formats into ours.
- **Entry points are thin**: gather inputs, call one context, handle listener callbacks.
- **Business rules** go in the context, steps, and roles; **implementation details** (persistence, formatting, delivery) go behind ports or inside role methods. When placement is a judgment call, say which in a comment.
- **Tests use fakes** for participants and ports, no database or network for business rules, and are table-driven over business cases.
- **Abstract only after two concrete cases**; label shortcuts where they live (`ABSTRACTION_NEEDED: …`).

When adding an operation: name it, draft and confirm its `RULES.md`, copy its process into the context's procedure comment, write the context's main method against roles and steps that don't exist yet, then write the roles, steps, listener, ports, and tests.
