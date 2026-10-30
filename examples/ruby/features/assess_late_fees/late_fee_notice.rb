module AssessLateFees
  # Port: tells someone a late fee was added. Only this feature uses it, so it
  # lives in the feature folder. Implementations raise NoticeFailed when they
  # cannot deliver.
  #
  # Telling the customer is a business requirement (R6), so the context has no
  # default notice: production must pass a real one. NullLateFeeNotice exists for
  # previews and tests that say explicitly they do not want notices.
  class StdoutLateFeeNotice
    def initialize(out = $stdout)
      @out = out
    end

    def late_fee_added(to:, invoice:, fee_cents:)
      @out.puts "Told #{to} about a #{format('$%.2f', fee_cents / 100.0)} late fee on #{invoice.number}"
    end
  end

  class NullLateFeeNotice
    def late_fee_added(to:, invoice:, fee_cents:)
      # no-op
    end
  end
end
