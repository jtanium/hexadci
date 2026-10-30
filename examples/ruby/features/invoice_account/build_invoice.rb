module InvoiceAccount
  # An invoice is dated the day it is built, addressed to the account's billing
  # recipients, and lists every uninvoiced charge on its own line, so the total is
  # exactly what the account owes for the period. (Business rule R2.)
  class BuildInvoice
    def self.call(invoice:, account:, charges:, on:)
      new(invoice: invoice, account: account, charges: charges, on: on).call
    end

    def initialize(invoice:, account:, charges:, on:)
      @invoice = invoice
      @account = account
      @charges = charges
      @on      = on
    end

    def call
      @invoice.date!(@on)
      @invoice.address_to!(@account.recipients)
      @charges.each do |charge|
        @invoice.add_line!(description: charge.description, amount_cents: charge.amount_cents)
      end

      @invoice
    end
  end
end
