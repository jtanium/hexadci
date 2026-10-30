module AssessLateFees
  # The account, in the role of "the customer whose invoice is overdue".
  class Customer
    def initialize(account, notice:)
      @account = account
      @notice = notice
    end

    def id
      @account.id
    end

    def on_payment_plan?
      @account.on_payment_plan == true
    end

    def bank_account_number
      @account.bank_account_number
    end

    def unwrap
      @account
    end
  end

  class DirectCustomer < Customer
    def notify_of_late_fee!(invoice, fee_cents)
      @notice.late_fee_added(to: @account.company_email, invoice: invoice.unwrap, fee_cents: fee_cents)
    end
  end

  class ResellerCustomer < Customer
    # A customer who came through a reseller is the reseller's to manage: we
    # tell the reseller about the fee and never contact the customer directly.
    # Everyone else hears from us at their billing address. (Business rule R6.)
    def notify_of_late_fee!(invoice, fee_cents)
      @notice.late_fee_added(to: @account.reseller_email, invoice: invoice.unwrap, fee_cents: fee_cents)
    end
  end
end
