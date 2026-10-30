module AssessLateFees
  # What every invoice role in this feature shares: its number, its customer,
  # and the notices owed for fees already added.
  class LateFeeInvoice
    attr_reader :customer

    def initialize(record, customer:)
      @record = record
      @customer = customer
    end

    def number
      @record.number
    end

    def unsent_late_fees
      @record.late_fees.reject(&:notice_sent)
    end

    def mark_notice_sent!(fee)
      fee.notice_sent = true
      @record.save!
    end

    def unwrap
      @record
    end
  end

  # The invoice, in the role of "an open invoice that may owe a late fee".
  class ChargeableInvoice < LateFeeInvoice
    DAYS_PAST_DUE_BEFORE_A_FEE = 30
    DAYS_BETWEEN_FEES          = 30
    MINIMUM_FEE_CENTS          = 500

    # An invoice owes a late fee once it is more than 30 days past due, and
    # then at most once every 30 days, so a customer is never charged twice for
    # the same month of lateness. (Business rule R1.)
    def due_for_late_fee?(on)
      more_than_30_days_past_due?(on) && no_late_fee_in_the_last_30_days?(on)
    end

    # A late fee is 1.5% of what the customer owes, but never less than $5.00,
    # so small balances still carry a meaningful fee. Half a cent rounds up.
    # (Business rule R3.)
    def late_fee_cents
      [one_and_a_half_percent_of_the_balance, MINIMUM_FEE_CENTS].max
    end

    # A customer who has already paid should not be charged a fee. The invoice
    # counts as paid when a cleared deposit names it and covers the balance. A
    # pending deposit does not count yet. One bank transaction can pay only one
    # invoice, even when the bank reports it for two customers who share an
    # account. (Business rule R4.)
    def covering_deposit(deposits, already_applied:)
      deposits.find do |deposit|
        deposit.cleared &&
          covered_by?(deposit) &&
          named_in?(deposit) &&
          !already_applied.include?(deposit.transaction_id)
      end
    end

    def add_late_fee!(fee_cents, on:)
      fee = LateFee.new(amount_cents: fee_cents, assessed_on: on)
      @record.late_fees << fee
      # DECISION D1: the fee becomes part of what the customer owes, so later fees
      # are figured on it and a deposit must cover it too. Confirm with Finance.
      @record.balance_cents += fee_cents
      @record.save!
      fee
    end

    def mark_paid!
      @record.status = 'paid'
      @record.save!
    end

    # How our records answer those questions: dates, money, and memo text.

    def more_than_30_days_past_due?(on)
      (on - @record.due_date).to_i > DAYS_PAST_DUE_BEFORE_A_FEE
    end
    private :more_than_30_days_past_due?

    def no_late_fee_in_the_last_30_days?(on)
      @record.late_fees.all? { |fee| (on - fee.assessed_on).to_i >= DAYS_BETWEEN_FEES }
    end
    private :no_late_fee_in_the_last_30_days?

    def one_and_a_half_percent_of_the_balance
      (@record.balance_cents * 15 + 500) / 1000 # 1.5%, rounding half a cent up
    end
    private :one_and_a_half_percent_of_the_balance

    def covered_by?(deposit)
      deposit.amount_cents >= @record.balance_cents
    end
    private :covered_by?

    def named_in?(deposit)
      deposit.memo.scan(/[A-Za-z0-9-]+/).any? { |token| token.casecmp?(number) }
    end
    private :named_in?
  end

  # Customers on a payment plan have already agreed a schedule with Finance,
  # so they never get late fees, and their invoices are not even checked at the
  # bank. (Business rule R2.)
  class PaymentPlanInvoice < LateFeeInvoice
    def due_for_late_fee?(_on)
      false
    end
  end
end
