require 'date'

module InvoiceAccount
  class Context
    def self.call(account:, charges:, notifier:, on: Date.today, listener: NullListener.new)
      new(account: account, charges: charges, notifier: notifier, on: on, listener: listener).call
    end

    def initialize(account:, charges:, notifier:, on:, listener:)
      @account  = cast_account(account, notifier)
      @charges  = charges
      @on       = on
      @listener = listener
    end

    # To invoice an account:
    #   1. if the account has no uninvoiced charges, there is nothing to do
    #   2. build a draft invoice from the charges
    #   3. if its total is far out of line with past invoices, hold it for review
    #   4. otherwise finalize it and notify the account
    def call
      # An account with nothing new to bill gets no invoice at all, not an empty
      # one. (Business rule R1.)
      if @charges.empty?
        @listener.nothing_to_invoice(@account.unwrap)
        return nil
      end

      invoice = DraftInvoice.new_for(@account)
      BuildInvoice.call(invoice: invoice, account: @account, charges: @charges, on: @on)

      if invoice.in_bounds?(@account.past_invoice_totals_cents)
        invoice.finalize!
        @account.notify_of_invoice!(invoice)
        @listener.invoice_finalized(invoice.unwrap)
      else
        # A held invoice waits for a person to review it, so nobody is told
        # about it yet. (Business rule R5.)
        invoice.hold!
        @listener.invoice_held(invoice.unwrap)
      end

      invoice.unwrap # control our return value
    end

    def cast_account(account, notifier)
      if account.billed_through_reseller
        ResellerBilledAccount.new(account)
      else
        DirectBilledAccount.new(account, notifier: notifier)
      end
    end
    private :cast_account
  end
end
