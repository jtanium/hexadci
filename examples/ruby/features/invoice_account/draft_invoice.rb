module InvoiceAccount
  # The invoice record, in the role of "the invoice being prepared".
  class DraftInvoice
    # Differences this small are never worth a human review.
    SMALL_DIFFERENCE_CENTS = 500
    # Fewer past invoices than this is too little history to judge an invoice by.
    INVOICES_NEEDED_FOR_A_HISTORY = 3

    def self.new_for(account)
      new(InvoiceRecord.new(account_id: account.id))
    end

    def initialize(record)
      @record = record
    end

    def date!(date)
      @record.invoice_date = date
    end

    def address_to!(recipients)
      @record.recipients = recipients
    end

    def add_line!(description:, amount_cents:)
      @record.lines << { description: description, amount_cents: amount_cents }
      @record.total_cents += amount_cents
    end

    def total_cents
      @record.total_cents
    end

    # An invoice goes out without review unless it is far out of line with what
    # this account usually pays. A new account has too little history to judge,
    # so its invoices always go out. Otherwise an invoice is in line when it is
    # within $5.00 of the account's average, or within the normal spread of its
    # past invoices (three standard deviations). (Business rule R4.)
    def in_bounds?(past_totals_cents)
      too_little_history?(past_totals_cents) ||
        close_to_average?(past_totals_cents) ||
        within_normal_spread?(past_totals_cents)
    end

    def hold!
      @record.status = 'held'
      @record.save!
    end

    def finalize!
      @record.status = 'final'
      @record.save!
    end

    def unwrap
      @record
    end

    # How "history" and "spread" are measured: arithmetic, not policy.

    def too_little_history?(past_totals_cents)
      past_totals_cents.length < INVOICES_NEEDED_FOR_A_HISTORY
    end
    private :too_little_history?

    def close_to_average?(past_totals_cents)
      (total_cents - mean(past_totals_cents)).abs <= SMALL_DIFFERENCE_CENTS
    end
    private :close_to_average?

    def within_normal_spread?(past_totals_cents)
      (total_cents - mean(past_totals_cents)).abs <= 3 * standard_deviation(past_totals_cents)
    end
    private :within_normal_spread?

    def mean(values)
      values.sum / values.length.to_f
    end
    private :mean

    # DECISION D1: the spread of all past invoices (population standard
    # deviation), not a sample estimate. See RULES.md.
    def standard_deviation(values)
      average = mean(values)
      Math.sqrt(values.sum { |v| (v - average)**2 } / values.length)
    end
    private :standard_deviation
  end
end
