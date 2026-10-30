module AssessLateFees
  # The result of one run: what Ops sees in the nightly summary.
  class Run
    attr_reader :late_fees, :found_paid, :not_processed, :warnings, :earlier_notices_sent
    attr_accessor :bank_unavailable

    def initialize
      @late_fees     = [] # [invoice number, fee cents]
      @found_paid    = [] # invoice numbers
      @not_processed = [] # [invoice number, reason]
      @warnings      = [] # [invoice number, reason]
      @earlier_notices_sent = [] # invoice numbers (R9)
      @bank_unavailable = nil
    end

    def late_fee_total_cents
      @late_fees.sum { |_number, cents| cents }
    end

    # Impossible results (N1-N3 in RULES.md) mean something upstream is wrong; stop loudly.
    #
    # This is a diagnostic, not the guard: by the time it runs, changes have been
    # made. The guards are the bank gate (R5) and duplicate rejection (R8), which
    # act before anything changes.
    def check_totals!
      if @bank_unavailable && (@late_fees.any? || @found_paid.any?)
        raise ImpossibleRun, 'invoices were changed although the bank was unavailable'
      end
      if @late_fees.any? { |_number, cents| cents < ChargeableInvoice::MINIMUM_FEE_CENTS }
        raise ImpossibleRun, "a late fee is below the minimum: #{@late_fees.inspect}"
      end

      changed = @late_fees.map(&:first) + @found_paid
      duplicates = changed.tally.select { |_number, count| count > 1 }.keys
      raise ImpossibleRun, "invoices changed more than once: #{duplicates.inspect}" if duplicates.any?
    end
  end
end
