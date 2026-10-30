module AssessLateFees
  # Checking the bank means: fetch recent deposits for every customer with an
  # invoice due a late fee, before anything is changed.
  #
  # BankUnavailable is deliberately not caught: the context decides what an
  # outage means for the run. An unreadable deposit only affects that
  # customer, so it is kept and raised when their deposits are asked for.
  class CheckBank
    def self.call(invoices:, bank:)
      new(invoices: invoices, bank: bank).call
    end

    def initialize(invoices:, bank:)
      @invoices = invoices
      @bank = bank
    end

    def call
      customers = @invoices.map(&:customer).uniq(&:id)
      BankCheck.new(customers.to_h { |customer| [customer.id, deposits_for(customer)] })
    end

    def deposits_for(customer)
      RetrieveDeposits.call(bank: @bank, bank_account_number: customer.bank_account_number)
    rescue UnrecognizedDeposit => e
      e
    end
    private :deposits_for
  end

  class BankCheck
    def initialize(deposits_by_customer_id)
      @deposits_by_customer_id = deposits_by_customer_id
    end

    def deposits_for(customer)
      deposits = @deposits_by_customer_id.fetch(customer.id)
      raise deposits if deposits.is_a?(RecordProblem)

      deposits
    end
  end
end
