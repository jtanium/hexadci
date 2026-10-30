require 'minitest/autorun'
require 'date'
require_relative '../features/invoice_account'

# Records every message it receives, so tests can assert on outcomes.
class RecordingListener
  attr_reader :events

  def initialize
    @events = []
  end

  def nothing_to_invoice(account)
    @events << [:nothing_to_invoice, account]
    :listener_return_value_should_be_ignored
  end

  def invoice_finalized(invoice)
    @events << [:invoice_finalized, invoice]
    :listener_return_value_should_be_ignored
  end

  def invoice_held(invoice)
    @events << [:invoice_held, invoice]
    :listener_return_value_should_be_ignored
  end
end

class FakeNotifier
  attr_reader :sent

  def initialize
    @sent = []
  end

  def invoice_ready(recipients:, invoice:)
    @sent << { recipients: recipients, invoice: invoice }
  end
end

module Factories
  def account(**overrides)
    Account.new(**{ id: 7, name: 'Example Coffee', company_email: nil,
                    billing_contacts: [], contacts: [], billed_through_reseller: false,
                    past_invoice_totals_cents: [] }.merge(overrides))
  end

  def contact(name)
    Contact.new(name: name, email: "#{name.downcase}@example.test")
  end

  def charge(amount_cents, description = 'Fee')
    Charge.new(description: description, amount_cents: amount_cents)
  end
end
