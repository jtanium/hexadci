# Entry point (driving adapter): a CLI.
#
# It gathers inputs, calls the context, and lets the listener decide what the
# outcome means here. A web controller would pass `listener: self` and render
# in its callbacks instead.
require_relative '../features/invoice_account'
require_relative '../ports/notifier'

account = Account.new(id: 42, name: 'Example Coffee', company_email: 'billing@example.test',
                      billing_contacts: [], contacts: [], billed_through_reseller: false,
                      past_invoice_totals_cents: [10_000, 10_500, 9_800])
charges = [Charge.new(description: 'Monthly gateway fee', amount_cents: 2_995),
           Charge.new(description: 'Processing fees', amount_cents: 7_310)]

InvoiceAccount::Context.call(account: account, charges: charges,
                             notifier: StdoutNotifier.new,
                             listener: InvoiceAccount::PrintingListener.new)
