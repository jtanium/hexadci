module InvoiceAccount
  # The outcomes of invoicing an account. A caller passes any object that
  # responds to these messages; a controller usually passes itself.
  class NullListener
    def nothing_to_invoice(account)
      # no-op
    end

    def invoice_finalized(invoice)
      # no-op
    end

    def invoice_held(invoice)
      # no-op
    end
  end

  # Turns on output for this feature only, e.g. from a CLI or while debugging.
  class PrintingListener
    def initialize(out = $stdout)
      @out = out
    end

    def nothing_to_invoice(account)
      @out.puts "Nothing to invoice for #{account.name}"
    end

    def invoice_finalized(invoice)
      @out.puts "Finalized invoice for account #{invoice.account_id}: #{dollars(invoice.total_cents)}"
    end

    def invoice_held(invoice)
      @out.puts "Held invoice for account #{invoice.account_id} for review: #{dollars(invoice.total_cents)}"
    end

    def dollars(cents)
      format('$%.2f', cents / 100.0)
    end
    private :dollars
  end
end
