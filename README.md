# HexaDCI for AI assistants

*HexaDCI* (pronounced "hex-a-dess-see") is short for hexagonal DCI.

A guide that teaches AI coding assistants to help people define business rules clearly, and then to write business logic in the HexaDCI style: a rule sheet and one folder per business operation, a Context that reads like the business process, feature-local roles, listeners and ports at the edges, and tests with fakes.

HexaDCI was developed by Jason Edwards between 2015 and 2020 in a production Ruby ERP that ran a payments business — billing, merchant and gateway accounts, account opening and activation — where other developers on the team also built features in it. This package restates the architecture in language-neutral form. **The examples are newly written and contain no code from that system.**

**New to the idea? Start with [`WHY.md`](WHY.md)** — the problem it solves, the theory behind it, what it buys you, and what it costs.

## What's here

| Path | Purpose |
|---|---|
| `WHY.md` | For people: the problem, the theory (DCI, hexagonal architecture, process vs procedure vs rule), the benefits, and the costs. |
| `SKILL.md` | The skill: core rules and workflows. Loaded by assistants that support Agent Skills. |
| `references/defining-business-rules.md` | Process vs procedure vs rule, the stakeholder question list, the `RULES.md` template, and extracting rules from existing code. |
| `references/patterns.md` | Each pattern with rationale and sketches. |
| `references/anti-patterns.md` | What to avoid, including drift from the original system and common AI mistakes. |
| `references/language-notes.md` | How the concepts map to Ruby, Python, TypeScript, Dart/Flutter, Java/Kotlin, C#, and Go. |
| `examples/{ruby,python,typescript,dart}/` | Two complete features with tests and a `RULES.md` each, written the same way in each language: `invoice_account` (single record) and `assess_late_fees` (batch). Every rule ID in a `RULES.md` is tagged in exactly one place in the code. |
| `.claude-plugin/` | Plugin and marketplace manifests, so Claude Code can install this repository as a plugin. |
| `AGENTS.snippet.md` | A condensed version to paste into `AGENTS.md`, `CLAUDE.md`, `.cursorrules`, or similar project instruction files. |

## Installing

**Claude Code, as a plugin** (recommended) — in a session:

```
/plugin marketplace add jtanium/hexadci
/plugin install hexadci@hexadci
```

or from your shell:

```bash
claude plugin marketplace add jtanium/hexadci
```

```bash
claude plugin install hexadci@hexadci
```

Claude uses the skill automatically when the work involves business rules; you can also invoke it as `/hexadci:hexadci`. Updates arrive when the plugin's `version` changes.

**Claude Code, as a plain skill** — clone the repository and copy or link it into a skills directory:

- for one project: `<project>/.claude/skills/hexadci/`
- for all your projects: `~/.claude/skills/hexadci/`

**Claude apps** — zip the folder (without `.git`, `node_modules`, and `.dart_tool`) and upload it as a custom skill.

**Other assistants** — paste `AGENTS.snippet.md` into the project's instruction file (`AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, `.cursorrules`). Point the assistant at `references/` and `examples/` if it can read files.

## Running the examples

Ruby (3.x, standard library only), from `examples/ruby`:

```bash
for f in test/*/*_test.rb; do ruby "$f"; done
```

```bash
ruby bin/invoice_account.rb
```

```bash
ruby bin/assess_late_fees_nightly.rb
```

```bash
ruby bin/assess_late_fees_for_account.rb 1
```

Python (3.10+, standard library only), from `examples/python`:

```bash
python3 -m unittest discover -s tests -t .
```

```bash
python3 -m bin.invoice_account
```

```bash
python3 -m bin.assess_late_fees_nightly
```

```bash
python3 -m bin.assess_late_fees_for_account 1
```

TypeScript (Node 22.6+), from `examples/typescript`:

```bash
npm install && npm test && npm run typecheck
```

```bash
npm run demo && npm run demo:late-fees && npm run demo:late-fees-account
```

Dart (3.5+), from `examples/dart`:

```bash
dart pub get && dart analyze && dart test
```

```bash
dart run bin/invoice_account.dart && dart run bin/assess_late_fees_nightly.dart && dart run bin/assess_late_fees_for_account.dart 1
```

When packaging the skill (zip upload or copying into a project), leave out `examples/typescript/node_modules` and `examples/dart/.dart_tool`; both are recreated by the install commands above.

## Verification status

- Ruby: 47 tests pass under `ruby -w` (Ruby 3.4.4); all three entry points run.
- Python: 41 tests pass with warnings as errors (Python 3.12.10); all three entry points run.
- TypeScript: 59 tests pass and `tsc --noEmit` is clean (Node 26.13.0, TypeScript 5.8+).
- Dart: 54 tests pass and `dart analyze` (recommended lints, strict casts and raw types) reports no issues (Dart 3.12.0); all three entry points run.
- In every language, each rule ID in a feature's `RULES.md` is tagged exactly once in code, and each process step matches the context's procedure comment.

## Trials

**2026-10-29, Python, late fees.** A fresh agent with only this skill implemented a late-fee request written by a finance stakeholder in an existing project. The request included a payment-plan exemption, reseller notification, a vendor bank API, per-invoice error isolation, a run-wide "bank down, charge nobody" rule, and nightly and single-customer entry points. It produced one feature folder, casting on two axes, a bank boundary translator, a listener per entry point, unchanged models, and 46 passing table-driven tests.

The skill was then revised from the agent's feedback:
- Null implementations are now limited to ports where doing nothing is safe.
- There is a fallback for when no one can be asked about an unclear rule.
- Patterns were added for casting on several axes and for participants that can't be cast.
- A batch skeleton was added, with a precondition gate and narrow per-record catches.
- There is new guidance on where queries go, folder layout in existing projects, and testing roles that save.

**2026-10-29, Python, commission payouts.** A second fresh agent, with the revised skill, implemented a Sales Ops request for monthly commission payouts. The request included tiered rates across an agent's whole book, clawbacks for merchants closed within 90 days, negative carry-forward, held pay for suspended agents, a vendor payroll API whose timeouts may or may not have paid, a no-double-payment rule for re-runs, a rule that contradicted itself on payroll outages, and a read-only portal preview. It produced a commit point per payout, deterministic idempotency keys in the payroll translator, "unconfirmed" as an outcome distinct from "failed", a preview with no effectful ports, and 45 passing tests.

Its main gap was in stating the rules, not structuring the code. It marked 5 of its 11 judgment calls as decisions and left the rest in its report only; one unmarked call meant that a crash between a payment and its statement email would lose the statement for good. That led to:
- The business-rules part of the skill: process vs procedure, the question list, `RULES.md` per feature with rule IDs tagged once in code, and the extraction workflow for existing code.
- Patterns for re-runs and idempotency.
- Guidance on read-only previews, on branching on outcomes vs participant types, and on which way "cautious" points when money can go wrong either way.

**2026-10-29, external review.** A reviewer found three bugs in the late-fee example that every test missed:
- **Duplicates** were caught only by an end-of-run check, after the fees and notices had already gone out.
- **Deposits** were allocated by object identity, so one bank transaction could pay two invoices when two customers shared a bank account.
- **Failed notices** were reported but never retried, because a re-run skips invoices it already charged.

All three are now fixed in all four languages, as rules R8 and R9 plus a revised R4, each with tests that reproduce the bug. The review also changed the instructions:
- **Proportion.** Choose the smallest implementation that keeps rule ownership clear and the interaction readable, and scale questioning and inventories to the uncertainty.
- **The rules conversation** is now guided rather than a questionnaire. Each rule records its source (stated, inferred or proposed), interacting rules get their own probe, and only unresolved decisions need confirming.
- **Port defaults follow business policy.** A required customer notice has no null default.
- **Debugging warns that a printing listener does not make a re-run safe.**
- **Process vs procedure is a thinking aid,** since the communication channel can itself be a requirement.

**2026-10-29, freecell migration (real project).** Testing the skill on a Flutter game led to more changes:
- **Pure operations.** A pure operation (game rules) is now told apart from a business operation with effects.
- **Feature-local types.** "Feature-local" means used only by that operation.
- **Roles attach behavior.** Roles add behavior to the data object, through scoped extensions where the language has them, rather than copying it.
- **The context file holds only the process.**
- **Rule explanations are plain language at the rule itself.**
- **Rules and implementation are separated.** Rule-level code states policy in business terms, implementation detail sits beneath it, and the two kinds of change go in separate commits.

The examples in all four languages were restyled to match as an implementation-only change, and every test file stayed byte-identical. The rule tests passing unchanged is the proof that no rule changed.

**2026-10-29, Python, rules extraction.** A third fresh agent got a small app in which the rules for suspending accounts for non-payment were spread across a controller, a model property and save hook, a SQL query, a nightly job, config, a database constraint and trigger, a payment-gateway sync, a template, and browser JavaScript, along with a Collections request to explain the rules without changing anything. Against a key of 17 planted rules and conflicts, it found 16 fully and 1 partly, all stated in business terms with locations. It found five more real behaviors that were not planted, changed no production code, and pinned current behavior with 24 passing characterization tests. Its feedback led to inventory rows (`I`) distinct from confirmed rules (`R`), questions for the owner (`Q`) distinct from your own decisions (`D`), rule sheets living in the feature folder before any code moves, characterization tests as an explicit exception to the no-database rule, and how to handle rules that only run in templates or the browser.

## License

MIT. See [`LICENSE`](LICENSE).
