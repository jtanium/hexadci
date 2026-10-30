# Hex-DCI patterns

Sketches use neutral pseudocode. See `examples/` for complete, idiomatic code in Ruby, Python, and TypeScript.

## Contents

1. Feature folder
2. Context
3. Casting roles
4. Roles
5. Steps
6. Listeners
7. Ports and null objects
8. Boundary translators
9. Contributors
10. Business rule vs. implementation detail
11. Validation as a business rule
12. Diagnostics
13. Testing
14. Labeling debt
15. Pure operations
16. Sharing across features

---

## 1. Feature folder

```
features/invoice_account/          tests/invoice_account/
  context                            context_test
  build_invoice        (step)        build_invoice_test
  draft_invoice        (role)        draft_invoice_test
  billing_accounts     (roles)
  listener             (protocol + null)
  NOTES.md             (optional design notes)
```

The folder name is the business operation. A developer asked to change "how accounts are invoiced" opens one folder and sees the whole operation, including its edge cases and its tests.

Feature-specific error classes, value objects, and result types live here too. Only things used by more than one operation move out.

## 2. Context

```
class InvoiceAccount.Context
  static call(account, charges, notifier, listener = NullListener) -> Invoice

  constructor(account, charges, notifier, listener)
    self.account  = cast_account(account, notifier)   # see 3
    self.charges  = charges
    self.listener = listener

  # To invoice an account:
  #   1. build a draft invoice from the account's uninvoiced charges
  #   2. if the total is out of line with past invoices, hold it for review
  #   3. otherwise finalize it and notify the account
  call()
    invoice = DraftInvoice.new_for(account)
    BuildInvoice.call(invoice, account, charges)

    if invoice.in_bounds?(account.past_invoice_totals)
      invoice.finalize!
      account.notify_of_invoice!(invoice)
      listener.invoice_finalized(invoice.unwrap)
    else
      invoice.hold!
      listener.invoice_held(invoice.unwrap)

    return invoice.unwrap           # control the return value
```

- One static/class-level entry point; keyword or named arguments.
- A context may expose more than one entry point when the business has distinct intents (`schedule` vs `close_now`).
- The comment block and the main method must agree. Update both together.
- Keep the main method short enough to read at a glance. Push detail into steps and roles.

## 3. Casting roles

The context decides what each participant *is* for this operation, once:

```
cast_account(account, notifier)
  if account.billed_through_reseller
    return ResellerBilledAccount(account)        # reseller sends invoices themselves
  return DirectBilledAccount(account, notifier)
```

After casting, the context and steps call `account.notify_of_invoice!(invoice)` without knowing which kind it is.

The caller may also cast, when the entry point already knows the role:

```
CloseMerchantAccount.Context.call(CloseableMerchantAccount(MerchantAccount.find(id)))
```

**Why:** the rule that distinguishes kinds of participant lives in one place, named in business terms. Adding a third kind means one new role class and one new branch.

**Several axes.** Cast each participant on its own axis, and let a role hold the roles of related participants. Do not multiply classes (`PaymentPlanResellerInvoice`…).

```
constructor(invoices, accounts, notifier)
  customers = { a.id: cast_customer(a, notifier) for a in accounts }    # reseller vs direct
  self.invoices = [ cast_invoice(i, customers[i.account_id]) ... ]      # payment plan vs chargeable

cast_invoice(invoice, customer)
  if customer.on_payment_plan  return PaymentPlanInvoice(invoice, customer)   # never due a late fee
  return ChargeableInvoice(invoice, customer)
```

Later code calls `invoice.customer.notify_of_late_fee(...)` without checking either axis.

**Participants that cannot be cast** (an invoice whose account is missing) are set aside in the constructor and reported to the listener as the first step of the procedure. They are an outcome, not an exception.

## 4. Roles

```
class InvoiceAccount.DraftInvoice
  constructor(record)       self.record = record
  static new_for(account)   return DraftInvoice(InvoiceRecord(account_id = account.id))

  add_line(description, amount)   ...
  total()                         ...
  in_bounds?(past_totals)         # business rule: see comment in example
  hold!()                         record.status = "held";  record.save()
  finalize!()                     record.status = "final"; record.save()
  unwrap()                        return record
```

- A role gives one data object the behavior this operation needs, and only that.
- Role methods use the operation's vocabulary. A `Billing.Invoice` record does not grow an `in_bounds?` method that every other part of the app can see.
- Never mutate the shared class, prototype, or instance (no monkey-patching, no global mixins), so concurrent operations cannot leak behavior into each other.

### Roles as scoped extensions

In languages with **scoped extensions** — Dart `extension`, Kotlin extension functions, C# extension methods — a role that adds behavior and holds no state of its own can be declared directly on the shared type, in a feature file. The methods exist only where the feature imports them, which is exactly DCI's "this object plays this role in this context." The context then reads as sentences about the domain objects themselves:

```dart
// features/play_move/move_roles.dart

/// The move, in the role of "a move being judged".
extension MoveBeingJudged on GameMove {
  /// A pile can't be moved back onto the column it came from. Nothing on the
  /// board would change, yet the old game counted it as a move, which cost the
  /// player a move for nothing — so it is refused instead.
  /// (Business rule R4; decided in D3.)
  bool get isOntoItself => from == to;
}

// How a move's representation answers "where from?" and "where to?" is an
// implementation detail; it lives on GameMove itself or in a separate
// implementation-level extension (see §10).
```

```dart
// features/play_move/play_move.dart — the context file: process comment and main method, nothing else

// To play a move:
//   1. a pile can't go back where it came from
//   2. take the pile from the top of its source
//   3. place it at the destination, by that destination's rule
//   4. tell the player only what their difficulty lets them see
PlayResult playMove(TableauState board, GameMove move, Categories categories, {required CategoryVisibility visibility}) {
  if (move.isOntoItself) return const Refused(Refusal.ontoItself);

  final source = Source.of(move);
  final destination = Destination.of(move);

  final result = switch (source.take(board, categories)) {
    Refused refused => refused,
    Taken(:final pile, :final rest) => destination.place(pile, onto: rest, categories: categories),
  };
  return result.asSeenAt(visibility);
}
```

- **Name the extension after the role** (`MoveBeingJudged`, `InvoiceBeingBilled`). It must be named to be used from another file; an unnamed extension is private to the file that declares it, which tempts you to put it in the context file.
- Use a **wrapper class** instead when the role holds state of its own, when participants come in kinds with different behavior (extensions dispatch on the static type, so they cannot replace sealed role classes chosen by casting), or in languages without scoped extensions (Ruby, Python, TypeScript, Go).
- Ruby's refinements are scoped too, but they have sharp edges (no effect through `send` or `method`, file-level activation); prefer wrappers in Ruby, as the original Hex-DCI code did.

### Where things live in a feature folder

| File | Holds |
|---|---|
| the context file (`play_move.dart`, `context.rb`) | the process comment and the main method — nothing else |
| role files (`move_roles.dart`, `sources.dart`, `destinations.dart`, `billable_accounts.rb`) | role methods and role classes, each rule's natural-language doc comment at its implementation |
| step files | steps that make the process easier to read or test |
| result / error files | the result type, reason codes, feature-specific errors |
| `RULES.md` | the rule sheet the business reviews |

### How rule comments read

A rule's comment sits on the method or function that implements it and explains the rule the way the business would — what it is, why, the edge case people ask about, who decided — and ends with its ID:

```
/// Customers on a payment plan never get late fees: they have already agreed
/// a schedule with Finance, and a fee would break it. Their invoices are not
/// checked at the bank either, since nothing would be charged anyway.
/// (Business rule R2.)
```

Not `// Business rule R2: no fees for plan customers` above an `if` in the context. The context says what happens; the role says why.
- Delegation is explicit. Forward only the accessors the feature needs rather than delegating everything; the role's method list then documents what the operation depends on.
- Persistence and other concretions may live inside role methods (`hold!` saves). The context and steps never call the persistence API directly.

## 5. Steps

```
class InvoiceAccount.BuildInvoice
  static call(invoice, account, charges)

  # Building an invoice means: date it today, address it to the account's
  # billing recipients, and add one line per uninvoiced charge.
  call()
    for charge in charges
      invoice.add_line(charge.description, charge.amount)
```

- Same shape everywhere: a static `call` with named arguments, an instance doing the work.
- Open with a comment defining the business concept the step implements ("Pricing a transaction means…").
- A step may call roles and ports, never entry-point concerns.

## 6. Listeners

```
protocol InvoiceAccount.Listener
  invoice_finalized(invoice)
  invoice_held(invoice)

class InvoiceAccount.NullListener implements Listener   # all no-ops
class InvoiceAccount.PrintingListener implements Listener   # for CLI and debugging
```

Entry points choose the listener:

```
# web controller
def create
  InvoiceAccount.Context.call(account, charges, notifier, listener = self)
def invoice_finalized(invoice)  render "finalized", invoice
def invoice_held(invoice)       render "held", invoice

# CLI
InvoiceAccount.Context.call(account, charges, notifier, listener = PrintingListener())
```

- One listener method per business outcome, named for the outcome.
- The context never depends on what a listener returns.
- A printing listener is the per-feature "turn on output" switch for debugging.

## 7. Ports and null objects

Side effects go through injected ports. **Choose each port's default from business policy, not from whether the code would still run:**

| Port | Default | Why |
|---|---|---|
| Diagnostic listener, narration, optional audit trail | Null implementation | Doing nothing loses visibility but changes no business outcome and breaks no promise |
| A notifier the rules require ("the customer is told when a fee is added") | **No default** — callers pass a real one; tests and previews pass a fake or a recording notifier explicitly | Skipping it silently breaks a business requirement even though the charge is correct |
| Bank, pricing service, credit bureau, inventory | **No null version at all** | An empty or default answer would silently change decisions (charge someone who paid, price at zero). These ports must raise when unavailable |

A null implementation of a required port can still exist for previews and tests; what matters is that production code never gets it by default.

```
protocol Notifier         invoice_ready(recipients, invoice)
class EmailNotifier       ...real delivery...
class NullNotifier        invoice_ready(...)  # no-op
```

A factory may select the implementation from a business name:

```
Notification.for("payment_declined")  -> BillingProblemEmail
Notification.for(unknown)             -> NullNotification
```

Policy that says "nothing happens in this case" is a null role or null port, with a comment:

```
class ResellerBilledAccount
  # The reseller invoices this merchant themselves; we never contact the merchant.
  notify_of_invoice!(invoice)   # no-op
```

## 8. Boundary translators

One step per external system converts that system's language into the feature's language:

```
# This step is the boundary between us and the payment gateway's billing API.
# Its only job is translation: gateway field names and formats in,
# our names and types out.
class AssessProcessingFees.RetrieveGatewayTransactions
  call(gateway_account, period)
    summary = gateway_client.billing_summary(gateway_account.number, period)
    return [ { xid:          t["xid"],
               completed_at: parse_time(t["time_stamp"]),
               entry_method: t["entry_meth"],
               amount:       decimal(t["amount"]) } for t in summary["transactions"] ]
```

Nothing downstream sees `entry_meth` or `time_stamp`.

## 9. Contributors

When an operation gathers data from several heterogeneous sources, each source is an object that knows how to contribute to the result:

```
sources = [ ProcessingFeeActivities(period), MonthlyFeeActivities(period),
            AnnualFeeActivities(period),     PaymentActivities(payments_period) ]

for source in sources
  for activity in source
    residual = ResidualReport.find_or_new(activity.merchant_id, period)
    activity.contribute_to(residual)
    residual.save_contribution!
```

```
class ProcessingFeeActivity
  contribute_to(residual)
    residual.volume       += fee.volume
    residual.discount_fee += fee.discount_fee
```

Adding a revenue source is one new class added to the list.

## 10. Business rule vs. implementation detail

Ask of every piece of code: *would the business state this as a rule?*

| Business rule (context, step, role decision) | Implementation detail (port or role internals) |
|---|---|
| Voided transactions are not charged | How a transaction row is saved |
| Hold invoices that are far outside the account's history | Which table stores the hold flag |
| Resellers are not notified | Email template and delivery mechanism |
| Zero-amount fees are still calculated | Whether $0.00 lines are displayed |

When the placement is a judgment call, leave a one-line comment saying which it is and why. These comments are what let the next developer (or assistant) keep the boundary.

### Two levels of code, so changes stay apart

Rule-level code states the policy using business-level questions and commands. Implementation-level code answers those questions from whatever the data and systems actually are.

```dart
// features/play_move/move_roles.dart: rule level
extension MoveBeingJudged on GameMove {
  /// A pile can't be moved back onto the column it came from: nothing would
  /// change, yet the old game charged a move for it. (Business rule R4; decided in D3.)
  bool get isOntoItself => from == to;
}

// models/game_move.dart, or an implementation-level extension in the feature:
// how this representation of a move answers "where from?" and "where to?"
extension MoveEnds on GameMove {
  Place get from => switch (this) {
        ColumnToColumn(:final from) || ColumnToReserve(:final from) || ColumnToFoundation(:final from) => Column(from),
        ReserveToColumn(:final slot) || ReserveToFoundation(:final slot) => Reserve(slot),
      };
  Place get to => ...;
}
```

```ruby
# features/assess_late_fees/late_fee_invoices.rb: rule level
# An invoice is due a late fee when it is more than 30 days past due and has not
# had a fee in the last 30 days. (Business rule R1.)
def due_for_late_fee?(on)
  more_than_30_days_past_due?(on) && no_late_fee_in_the_last_30_days?(on)
end

# implementation level: how our records answer those questions
def more_than_30_days_past_due?(on) = (on - @record.due_date).to_i > 30
def no_late_fee_in_the_last_30_days?(on)
  @record.late_fees.none? { |fee| (on - fee.assessed_on).to_i < 30 }
end
```

What this buys, change by change:

| Change | Touches | Does not touch |
|---|---|---|
| Rule: "15 days after the due date, not 30" | `RULES.md`, the rule method or its constant, the rule's test rows | storage, representation, other rules |
| Implementation: moves become `GameMove(from:, to:)` | `MoveEnds` (or the model) | `isOntoItself`, `RULES.md`, rule tests — which pass unchanged |
| Implementation: invoices move from SQL to a document store | the record and its persistence | rule methods, `RULES.md`, rule tests |

**Commit them separately**, and say which kind each commit is ("rule: late fees start after 15 days", "impl: store invoices as documents"). The history then answers "when did the policy change?" by itself. If an implementation commit has to change a rule test, it changed a rule: split it, or treat the whole change as a rule change.

**Tests follow the same split.** Rule tests are written in business inputs and outcomes (an invoice 31 days past due, a move from a column to itself), through the rule-level methods, so they survive implementation changes. Implementation tests, where needed, check the decoding or the storage directly.

## 11. Validation as a business rule

Where acceptance criteria are business rules ("monthly volume must not exceed the product's limit," "a beneficial owner must hold at least 25%"), validate in the context or a step, against a small set of reusable helpers, and report invalid input to the listener:

```
call()
  require(registration, "legal_name")
  require_decimal(registration, "monthly_sales_estimate")
  if registration.monthly_sales_estimate > configuration.limit_for(product)
    invalid(registration, "monthly_sales_estimate", "exceeds the product limit")
  if not registration.valid
    listener.registration_invalid(registration)
    return registration
  ...
```

Field-format checks that are true everywhere (an email looks like an email) may stay on the data object.

## 12. Diagnostics

- **At the point of surprise**, report with context and continue if the business allows:
  ```
  diagnostics.warn("Unable to price transaction", where = (self, "call"), values = { xid, type })
  ```
- **Batch operations narrate** each step through the listener and **sanity-check** results:
  ```
  listener.progress("Compiling processing fees", count = n, seconds = t)
  if total_transactions <= 0  raise ImpossibleTotal("total transactions must be > 0")
  ```
- **Collect, don't halt**, when one bad record should not stop a batch: gather `warnings` and `failures` with the offending record and exception, and report them to the listener at the end.

### Batch operations

A batch context has a recognizable skeleton:

```
# To assess late fees:
#   1. report any invoice whose customer we cannot find; carry on with the rest
#   2. pick the invoices due a late fee today
#   3. check the bank for every customer with such an invoice, before charging
#      anyone; if the bank is down, charge nobody tonight
#   4. settle each due invoice; one bad invoice does not stop the others
#   5. sanity-check the results and report the summary
call()
  for invoice in uncastable        report_not_processed(invoice, "no account")

  due = [ i for i in invoices if i.due_for_late_fee(today) ]

  try   bank_check = CheckBank.call(due, bank)              # precondition gate
  catch BankUnavailable
        run.bank_unavailable = true
        return finish()                                     # nothing has changed yet

  for invoice in due   settle(invoice, bank_check)          # per-record isolation

  return finish()

settle(invoice, bank_check)
  try   ...business steps for one invoice...
  catch ExpectedRecordProblem as e     report_not_processed(invoice, e)

finish()
  run.check_totals()                   # raise on impossible results
  listener.run_finished(run)
  return run                           # control the return value
```

- **Validate identities before any change.** If the same record can arrive twice (a duplicated row, two entry points feeding one run), reject or deduplicate by business identity — invoice number, not object identity — and report the repeat, before anything is charged or sent. An end-of-run "handled twice" check is a diagnostic; by the time it fires, the damage is done.
- **Allocate external items by their external identity.** When one external item can satisfy several records (a deposit naming two invoices; two customers sharing a bank account and so receiving the same deposit twice), keep the external system's stable ID (the bank's transaction ID) through the boundary translator and track allocation by that ID. Object identity breaks as soon as the same item is fetched or translated twice.
- **Precondition gate.** A run-wide rule ("if the bank is down, charge nobody") is checked *before any change is made*, by gathering everything the decisions need first. Then the all-or-nothing rule and per-record isolation never conflict.
- **Catch narrowly.** Catch the error types a record can legitimately cause (bad data from a boundary, a missing related record, a declined payment) and report them. If you must catch broadly to protect the batch, report the exception type and traceback, and make sure a sanity check or test would notice a sudden rise in failures. Never let a programming error look like a data problem.
- **Side effects after the decision, with their own state.** Persist the business change, then notify. If the notice fails, the business change stands — and the notice must be recoverable: record that it is unsent (on the fee, the payout, a notice table) and send unsent notices on the next run. A warning alone is not recovery: a re-run skips records it already changed, so the notice is lost for good. If automatic retry is not wanted, write the manual recovery step into `RULES.md`.
- **Result object.** Return a run/result object (counts, totals, failures, warnings) that the listener also receives. Give it a `check_totals()` that raises on impossible values.
- **Scope comes from the entry point.** The nightly job passes everything; a CLI passes one customer. Same context, same rules.

See `examples/*/…/assess_late_fees/` for this skeleton implemented and tested in Ruby, Python, and TypeScript.

### Re-runs and effects that must not happen twice

When a batch can crash partway and be re-run, or calls something that must never happen twice (a payment, a payout, a shipment):

- **One commit point per record.** Record the business decision for each record (e.g. a `Payout` row for this agent and month, status `pending`) *before* calling the external system. A re-run reads it: settled records are skipped, `pending` ones are resumed — never recalculated into a second decision.
- **Idempotency keys belong in the boundary translator.** Derive the key from the business identity of the effect (`commission-2026-09-agent-17`), not from a random value or a timestamp, so a re-run sends the same key and the provider returns the original result.
- **"Unknown" is its own outcome.** A timeout from a payment provider means *may or may not have happened*. Record it as unconfirmed, not as failed; the re-run resumes it with the same key.
- **Order writes so a re-run can recover.** Set derived balances from the committed record (*set*, not *add*), so applying the same record twice has no extra effect.
- **Follow-up effects need their own state.** If a statement email must go out after a payment, record whether it was sent; otherwise a crash between the two leaves the payment done and the email lost forever, because the re-run skips settled records.
- **Write the re-run rules in `RULES.md`** ("a re-run never pays anyone twice and finishes any unconfirmed payment") and test them: crash after the external call, re-run, assert one effect.

## 13. Testing

- Test each step and the context directly, with **fakes** for participants and ports. No database, network, or web framework in business-logic tests.
- Fakes respond only to the role messages the code uses. If a test needs a fake to answer something new, the operation's dependency list just grew; that is worth noticing.
- **Table-driven cases** over business inputs, so the test file reads as the rulebook:
  ```
  for type in ["sale", "postauth", "force"]
    test "accepted {type} is charged transaction and discount price"
  for type in ["credit", "preauth"]
    test "{type} is charged transaction price only"
  test "void is charged nothing"
  ```
- Test the **listener protocol**: assert which outcome method was called with what.
- Test **each role variant** of a casting decision.
- Keep a thin integration test per entry point for wiring; it does not re-test business rules.
- **Contexts that read back what they wrote** (resumable batches, history-dependent rules such as clawbacks) are best tested against an in-memory implementation of the real store or query port, reset per test, rather than a separate fake that re-implements its logic. Steps and roles can still use simple fakes.
- **Roles that save.** When a role's method persists through the data object (`hold!` calls `save()`), role tests touch persistence. Prefer, in order: data objects whose persistence can be swapped for an in-memory fake in tests; injecting a repository port into the role; or, with an existing ORM, a transaction or store reset per test. Context and step tests can still use fake roles and need none of this.

## 14. Labeling debt

Mark shortcuts where they live, with the reason and what would resolve them:

```
# ABSTRACTION_NEEDED: distributor credit pricing is hard-coded here. Abstract
# once a second distributor has special pricing and we can see the shape.
```

Do not build an abstraction for a single case. Two concrete cases, or a clearly established domain fact, justify one.

## 15. Pure operations

Some operations are a calculation or a judgment: values in, a result out, nothing else touched. Game rules, pricing a cart, checking eligibility, moving stock between locations on paper before anything ships. They still get the full benefit of DCI — a feature folder, a `RULES.md`, rule IDs, a context that reads like the process, and roles for participants that come in kinds. What they leave out is the machinery for effects: listeners, ports, null objects, exceptions for ordinary outcomes, and mutable copies of the input.

### The context reads like the process

```
# features/transfer_stock/

# To transfer stock:
#   1. take the items from their source
#   2. the items must all be the same product
#   3. put them at the destination, by that destination's rule
TransferStock.call(inventory, transfer) -> Transferred(new_inventory) | Refused(reason, facts)

call(inventory, transfer)
  if transfer.goes_nowhere              return Refused(SAME_PLACE)              # R4
  source      = Source.of(transfer)        # a shelf | a returns bin
  destination = Destination.of(transfer)   # a shelf | an order | scrap

  taken = source.take(inventory)
  if taken is Refused                   return taken
  return destination.put(taken.items, onto: taken.remaining_inventory)
```

A transfer is two independent things: where the items come from and where they go. If the request type enumerates the combinations (`ShelfToShelf`, `ShelfToOrder`, `ReturnsToScrap`, …), resist switching over the combinations in the context: every arm would have to take the request apart and re-wire the whole process, usually with callbacks, and the process stops reading like the process. **Cast each axis into a role** — once — and write the process once.

### Pure roles

```
class ShelfSource implements Source            # Business rule R1 lives here
  constructor(shelf_id, item_ids)
  take(inventory) -> Taken(items, remaining_inventory) | Refused
    shelf = inventory.shelf(shelf_id)
    if not shelf.holds_all(item_ids)    return Refused(NOT_ON_SHELF, {shelf_id})
    return Taken(items_of(item_ids), inventory.without(item_ids, from: shelf_id))

class OrderDestination implements Destination  # Business rules R5–R7 live here
  put(items, onto: inventory) -> Transferred | Refused
    ...
    return Transferred(inventory.with_items_on_order(order_id, items))
```

- **Roles hold immutable values and return results.** `take` and `put` never change their input; they return `Taken`, `Transferred`, or `Refused`. New inventory is built from the old one (`inventory.without(...)`, `inventory.with_items_on_order(...)`) — methods on the shared data type if they are broadly useful, small functions in the feature if not. Never copy every field of the input into a mutable working model and edit that.
- **Each role owns the rules about its kind.** The shelf owns "items must be on the shelf"; the order destination owns "an order can't take more than it asked for". Tag each rule where it is implemented.
- **Casting is the one place the request is taken apart.** `Source.of(transfer)` and `Destination.of(transfer)` map request types to roles; an exhaustive switch there is right. (In Dart, or-patterns bind the same fields across several request types in one case.)
- **Every outcome is a value.** Refusals carry a **reason code and the facts** behind it (which shelf, which order). The caller decides how to word it. If a rule says some facts must not be shown (a hidden answer in a game), the feature leaves them out of the refusal, so the UI cannot leak them by mistake.

### When a plain switch is enough

If the request varies along **one** axis and each kind is a single call into its own rule function — `BookRoom` vs `CancelBooking`, each one line in the context — a switch is clear, and roles add nothing. The signal that you need roles is a switch whose arms **restate the process**: take, check, place, repeated per case with different pieces plugged in.

### Around the pure operation

- **Effects stay outside.** Saving, undo history, updating the screen, and analytics live in the caller — a controller, a Cubit, a job — which calls the pure operation and acts on its result in a few lines. Test the caller's guarantees there (a refused move leaves the board, the move count, and the undo history untouched).
- **Shared vocabulary stays shared.** The request types and the inventory are the domain's types; other code uses them. They stay in the shared models. The feature folder holds the context, its roles, its result type, and `RULES.md`.
- **Tests are tables of input → result.** No fakes are needed. Each rule's examples become rows: (inventory, transfer) → expected `Transferred` or `Refused(reason)`.
- **Size check.** A pure operation migrated from an existing validator should not grow without a reason: merged duplicate checks usually make it smaller. If it grew, look for copies of the input, unused listeners, and classes that only forward calls — but do not trade readability for lines. A few small role classes that let the context read like the process are worth more than a compact switch nobody can read.

---

## 16. Sharing across features

Not everything can live in one feature folder. Two features need the same rule; a feature and the screen must agree on what the player may see; several operations start with the same authorization. The aim is still that each "what" has one home and one owner, and that a reader can find it from wherever it is used.

### What is shared, and where it goes

| What is shared | Example | Where it lives | In the original system |
|---|---|---|---|
| **Vocabulary** — the domain's data types | moves, the board, invoices, accounts | the shared models | models |
| **A rule** (a "what") that several features, or a feature and the UI, must apply identically | which category names the player can see; which customers count as reseller customers | a **shared role** in a folder named for the concept, e.g. `rules/category_sight/`, with its tests | traits (first generation) |
| **A sub-process** several contexts run as one step | authorize this user for this operation | a **small context of its own**, called as one step of each process | habits |
| **An implementation** (a "how") | charge a card through the gateway, save a record, parse a bank memo | a shared port, boundary translator, or data-object method | business models, `PaymentProcessor` |

The original Cardinality code tried the first two as generic `traits/` and `habits/` directories with a delegate-everything `Trait` base class, and marked them for removal. What went wrong was not sharing; it was **sharing with no owner**: a grab bag named for the mechanism ("traits") rather than the concept, where anything could be added and nothing said whose rule it was. The forms below keep the useful part.

### Share only what must agree by definition

Default to keeping a rule in its feature. Share it when there is a second real user **and** the two must agree, not merely happen to read alike. The test: *if this feature's owner changed the rule, must the other user change too?*

- Yes: "a refusal may name only categories the screen shows" — if they drift, the game leaks hidden names. One rule, shared.
- No: two fee features that both use 30 days today. If Finance changes late fees to 45 days, collections should not silently follow. Two rules that look alike; keep both concrete, each with its own ID.

### How a shared rule keeps its owner

- **One home in code, named for the concept** (`category_sight`, `reseller_customers`), never `shared/`, `common/`, `utils/`, or `traits/`. The folder holds the role(s), their tests, and — when no single feature owns the rule — its own `RULES.md` with an owner. It holds no context: it is not an operation.
- **One owner on paper.** Either:
  - the feature that defines the rule keeps it in its `RULES.md`, and the shared code cites it with a qualified ID: *"(Business rule R19 in features/play_move/RULES.md.)"* — right when one feature clearly owns the rule and the others only follow it; or
  - the shared folder has its own `RULES.md` (IDs like `category_sight R1`) — right when no feature is the natural owner.
- **Users cite it, never restate it.** Each feature's `RULES.md` that depends on a shared rule lists it under **Rules from elsewhere**: the qualified ID, one line saying what it decides, and the step that uses it. Restating it in the feature's own words is how two copies drift.
- **Dependencies point one way.** Shared rule code depends only on shared models. Features import it; it never imports a feature, and no feature imports another feature. If shared code needs something from a feature folder, that thing is shared too.
- **Scoped, not global.** A shared role is still a role: a scoped extension or wrapper that each user imports explicitly, so the import *is* the declaration "this feature follows that rule". It is never mixed into the model class for everyone.
- **Changing it is a rule change for every user.** Find them by the rule ID (and the import), get each owner's agreement, and run every user's tests. The commit says which rule changed and which features it affects.

### A shared sub-process

When several contexts begin with the same steps ("authorize the user for this operation"), make those steps a small context with its own name and process comment, and call it as one line in each process: `AuthorizeOperation.call(user, :list_merchant_accounts)`. Its rules belong to it, in its own `RULES.md`. Keep it a step, not a framework: no hooks, no base-class callbacks that run invisibly before every context.

### How languages help

How cleanly this works depends on what the language offers for scoping:

- **Dart, Kotlin, C#.** Scoped extensions fit exactly: `extension CategorySight on TableauState` in `lib/rules/category_sight/`, imported by the feature and the screen that use it (Dart's `show` can narrow what an import brings in).
- **Ruby.** A wrapper class in a namespaced module (`CategorySight::Board.new(board).can_see?(category)`), or a module of functions taking the record. Do not `include` it into the model; that makes it every operation's rule. Refinements are scoped by file but have sharp edges.
- **Python, TypeScript, Go.** A module of functions taking the data, or a small wrapper class, imported explicitly. In TypeScript, never prototype augmentation or declaration merging onto the shared type.

Whatever the language, the checks are the same: the shared rule has one home named for its concept, one owner, a citation from each user, and dependencies that point from features to it.

