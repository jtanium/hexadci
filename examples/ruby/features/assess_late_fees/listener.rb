module AssessLateFees
  # The outcomes of a late-fee run.
  class NullListener
    def invoice_not_processed(number, reason); end
    def late_fee_added(invoice, fee_cents); end
    def invoice_found_paid(invoice); end
    def late_fee_notice_failed(invoice, reason); end
    def earlier_notice_sent(invoice, fee_cents); end
    def bank_unavailable(reason); end
    def run_finished(run); end
  end

  # Nightly: only the summary Ops asked for.
  class SummaryListener < NullListener
    def initialize(out = $stdout)
      @out = out
    end

    def run_finished(run)
      if run.bank_unavailable
        @out.puts "BANK UNAVAILABLE (#{run.bank_unavailable}): no late fees were charged tonight"
      end
      @out.puts "Late fees added: #{run.late_fees.length}, total #{format('$%.2f', run.late_fee_total_cents / 100.0)}"
      @out.puts "Invoices found already paid: #{run.found_paid.length}"
      @out.puts "Notices from earlier runs sent: #{run.earlier_notices_sent.length}" if run.earlier_notices_sent.any?
      (run.not_processed + run.warnings).each { |number, reason| @out.puts "  #{number}: #{reason}" }
    end
  end

  # Single customer at the command line: narrate everything.
  class PrintingListener < SummaryListener
    def invoice_not_processed(number, reason)
      @out.puts "Could not process #{number}: #{reason}"
    end

    def late_fee_added(invoice, fee_cents)
      @out.puts "Added #{format('$%.2f', fee_cents / 100.0)} late fee to #{invoice.number}"
    end

    def invoice_found_paid(invoice)
      @out.puts "#{invoice.number} was already paid at the bank; marked paid"
    end

    def late_fee_notice_failed(invoice, reason)
      @out.puts "Late fee on #{invoice.number} stands, but the notice failed: #{reason}"
    end

    def earlier_notice_sent(invoice, fee_cents)
      @out.puts "Sent the notice for the earlier #{format('$%.2f', fee_cents / 100.0)} late fee on #{invoice.number}"
    end

    def bank_unavailable(reason)
      @out.puts "Bank unavailable (#{reason}); charging nobody"
    end
  end
end
