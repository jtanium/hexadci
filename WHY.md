# Why HexaDCI

HexaDCI asks you to think about code differently. Most of us were taught to organize software by *what kind of code it is*: models here, controllers there, services, jobs, helpers. HexaDCI organizes it by *what the business does*. That sounds like a filing change. It turns out to change how you read, change, test, and debug a system, and how you talk with the people who own its rules.

This page explains where the idea came from, the theory behind it, what it buys you, and what it costs. The skill itself (`SKILL.md` and `references/`) tells an AI assistant how to do it; this page is for the people deciding whether they want it.

## The problem: complexity hides

HexaDCI grew out of an ERP: the system that ran a payments business — billing, merchant and gateway accounts, opening and activating accounts, reporting. It was the backbone of the business, and like most backbones it had grown for years.

Jason Edwards set out to find a way to manage the complexity of systems like that. What he kept finding was business rules in places nobody would think to look: a small rule stuck in a script running on another server; a condition in a model callback; another in a SQL query; the same check, slightly different, in a controller and a nightly job. Model classes collected hundreds of methods, each serving some different operation. To understand one feature you had to visit a dozen files, and to be sure you had found every rule you had to visit all of them.

None of that is unusual. It is what happens when code is organized by technical layer:

```
app/
  models/invoice.rb          ← late-fee math, invoicing math, refund checks, …
  models/account.rb          ← reseller logic, payment-plan logic, …
  controllers/invoices_controller.rb   ← "don't charge if…"
  jobs/nightly_fees.rb       ← "skip if the bank is down"
  db/views/overdue.sql       ← "past due" means > 30 days … or 31?
  scripts/fix_fees.rb (on another server)  ← one more rule nobody remembers
```

Every one of those files can be well written, and the system can still be impossible to understand, because **the business operation itself — "assess late fees" — exists nowhere.** It exists only as a pattern spread across the code, and in the heads of the people who wrote it. The real cost shows up later:

- *"What exactly happens when a customer on a payment plan is 45 days late?"* becomes an investigation.
- A change to one rule misses the copy of it in the job, and the two drift apart.
- The person who knew why the threshold is 30 days leaves, and the reason leaves with them.
- Every bug starts with reverse-engineering what the original author meant.

## The shift: organize around the business operation

HexaDCI makes the business operation the unit of code. Each thing the business does gets its own folder, named the way the business would say it (simplified from the Python example):

```
features/
  assess_late_fees/
    RULES.md          ← the rules, in business words, with their reasons
    context.py        ← the process, step by step
    late_fee_invoices.py   ← what an invoice does *in this operation*
    customers.py      ← what a customer does *in this operation*
    check_bank.py     ← one step, pulled out because it talks to the bank
  invoice_account/
    …
models/               ← the data: invoices, accounts — shared, and thin
```

Want to know how late fees work? Open one folder. Read `RULES.md` for the rules and why they exist; read the context for the order things happen in. Everything that exists only for late fees is there, and nothing else is.

## The ideas it combines

**DCI — Data, Context, Interaction** (Trygve Reenskaug and James Coplien). DCI separates *what the system is* from *what the system does*:

- **Data** — invoices, accounts, moves, boards. Stable, shared, mostly just data.
- **Context** — one business operation. It gathers the objects involved and runs the process.
- **Interaction** — the behavior. Inside a context, each object plays a **role**, and the role gives it the behavior this operation needs. An invoice in the late-fees operation can answer `due_for_late_fee?`; an invoice anywhere else cannot, because that behavior belongs to late fees, not to invoices.

That last point is what stops models from collecting hundreds of methods. Behavior lives with the operation that needs it.

**Hexagonal architecture — ports and adapters** (Alistair Cockburn). The business logic sits in the middle and knows nothing about the outside world. The bank, the mail provider, the database, the web framework are reached through **ports** — small interfaces the operation defines in its own terms — and plugged in from the edge. The original system's README put it this way: business processes "are very abstract and should remain pure Ruby; concretions like ActiveRecord, JSON, CSV files should never be included."

Together: DCI makes the operation *readable* — the context reads like the business process. Hexagonal architecture keeps it *clean* — no infrastructure in the way of that reading, and nothing tying the rules to one database, one framework, or one interface.

## Process, procedure, and rule

The original documentation drew a distinction that is the heart of the way of thinking:

- A **business process** is what the business does and decides, in its own words: *"check the bank before charging anyone; if a deposit covers the invoice, mark it paid; otherwise add a late fee and tell the customer."*
- A **business procedure** is how one step gets carried out: *"write the fee to the database," "send the email through the mail provider."*
- A **business rule** is a decision the business made: *"1.5% of the balance, never less than $5."*

They change for different reasons. Processes and rules change when **policy** changes — Finance decides something. Procedures change when **technology** changes — you switch databases or mail providers. So HexaDCI keeps them in different code. A policy change touches the rules; a technology change touches the procedures; and each kind of change can be made, reviewed, and committed without disturbing the other.

## What it looks like

Here is the late-fee operation from the Python example. First the process — the context's main method, under a comment copied from `RULES.md`:

```python
# To assess late fees:
#   1. report any invoice whose account we cannot find, or that is listed more
#      than once; carry on with the rest
#   2. send any late-fee notice from an earlier run that did not go out
#   3. pick the invoices due a late fee today
#   4. check the bank for every customer with such an invoice, before
#      changing anything; if the bank is down, charge nobody tonight
#   5. for each due invoice: if a cleared deposit already covers it, mark it
#      paid; otherwise add a late fee and tell whoever handles the customer's
#      billing. One bad invoice does not stop the others
#   6. sanity-check the results and report the summary
def __call__(self) -> Run:
    ...
    due = [invoice for invoice in self._invoices if invoice.due_for_late_fee(self._on)]
    ...
```

Then the rules, each in one place, explained in plain language where they live:

```python
class ChargeableInvoice(_LateFeeInvoice):
    def due_for_late_fee(self, on: date) -> bool:
        """An invoice owes a late fee once it is more than 30 days past due, and
        then at most once every 30 days, so a customer is never charged twice for
        the same month of lateness. (Business rule R1.)"""
        return self._more_than_30_days_past_due(on) and self._no_late_fee_in_the_last_30_days(on)


class PaymentPlanInvoice(_LateFeeInvoice):
    """Customers on a payment plan have already agreed a schedule with Finance,
    so they never get late fees, and their invoices are not even checked at the
    bank. (Business rule R2.)"""

    def due_for_late_fee(self, on: date) -> bool:
        return False
```

Notice three things:

1. **The context never asks what kind of invoice it has.** The invoice was cast into its role once — chargeable, or on a payment plan — and from then on each kind answers for itself. The payment-plan exemption is not an `if` buried somewhere; it is a kind of invoice, with its reason written on it.
2. **The rule reads as the policy.** `due_for_late_fee` says *what* is decided. *How* the dates are compared sits beneath it, in methods that change if the data changes, not if the policy does.
3. **The "why" is written down.** "So a customer is never charged twice for the same month of lateness." The next person doesn't have to guess.

## The benefits

**You can find things.** Each business operation is one folder, named for what the business does. Each rule has exactly one home, with an ID that links it to its line in `RULES.md` and to its tests.

**You can change things safely.** A rule change touches `RULES.md`, the rule, and its tests. An implementation change — a new database, a new mail provider — touches only implementation code, and the rule tests passing *unchanged* proves no policy moved. Commit history says which kind of change each one was, so you can see when the policy changed and when only the technology did.

**You can tell what kind of mistake was made.** When code is wrong, either its author misunderstood **the goal** or misunderstood **how to implement** it. With only a mechanism (`days > 30`), those look identical. Once the rule is named and its reason stated, you can ask separately: *is the rule right for its purpose?* — a question for the business — and *does the code implement the rule?* — a question for engineering, which a test can answer. Different owners, different fixes, different commits.

**Institutional knowledge stays in the system.** Every "how" is labeled with its "what", and every rule carries its "why". A new developer — or an AI assistant — can learn what the system does and why by reading it, instead of by finding the person who remembers.

**Testing gets simple.** Business logic doesn't need a database, a web server, or the bank: the ports are swapped for fakes. Tests are tables of business cases taken straight from the rule sheet's examples — *30 days late: no fee; 31 days: fee* — so the test file reads like the rulebook.

**Debugging follows the business story.** Start from the complaint, find the operation, find the rule that decided, compare it with its purpose. Decision logs can record which rule decided what, from which facts.

**The rules are portable.** Because rules say "the customer asks to cancel", not "the customer clicks Cancel", the same feature can be driven from a web app, a desktop app, a command line, a nightly batch, or an API. The interface is just an entry point.

**You can talk with the business in its own terms.** The context reads like what the stakeholder said, so you can check it against them line by line. Jason's experience was that once the architecture was in place, building features became predictable — "almost boring": once someone explained a requirement, he could already picture most of the implementation. He began attending business meetings directly, which removed a layer of translation between the people who owned the rules and the code that carried them out.

**AI assistants do better work.** Assistants are even worse than people at reverse-engineering intent, and much more confident about it. An explicit rule sheet gives them something to work from, a single place to make each change, and a way for you to review their work: is the rule right, and does the code implement it?

## The costs

It isn't free, and it isn't for everything.

- **It is a different way of thinking.** The first features feel slower, because you have to state the rules before writing code and decide where each piece of behavior belongs. That front-loaded thinking is the point — but it has to be learned.
- **More, smaller files.** An operation that was ten methods spread across three models becomes a folder with a context, a couple of roles, and a rule sheet. You trade a few big files for one place to look.
- **Conventions need to be written down.** The architecture works when everyone shares its conventions. The original system's own history shows early forms that were later abandoned, such as generic "traits" and "habits" directories. Conventions that live only in the original team's heads don't survive the team; this package exists to write them down.
- **It is for business logic.** Plain create-read-update-delete screens with no rules, one-off scripts, and spikes should use the framework's conventions directly.

## Getting into the mindset

A few questions carry most of the way of thinking:

- **What business operation is this?** Name it as the business would: *assess late fees*, *close a merchant account*, *play a move*.
- **What are the rules, and why?** Write them down in business words, with examples at the boundaries, before writing code. If nobody knows why a rule exists, that's a question for the owner, not a gap to fill with a guess.
- **Would this sentence still be true if the app were a command-line tool?** If not, it's describing the interface, not the business.
- **Is this a policy change or a technology change?** Put the code — and the commit — where that answer says.
- **Could a newcomer tell what this line is for, and why, without asking me?** If not, it isn't finished.

## Where to go next

- `README.md` — what's in this package and how to install it.
- `examples/` — two complete features, with tests, in Ruby, Python, TypeScript, and Dart. Start with a `RULES.md`, then its `context` file.
- `references/defining-business-rules.md` — how to get clear rules out of a stakeholder, or out of existing code.
- `SKILL.md` — the full set of conventions, as given to an AI assistant.
