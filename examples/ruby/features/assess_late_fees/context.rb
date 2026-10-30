require 'date'
require 'set'

module AssessLateFees
  # Assess late fees on a set of open invoices. The nightly job passes every
  # open invoice; the single-account CLI passes one account's. Same rules.
  class Context
    # `notice` has no default: telling the customer is required (R6).
    # The listener is diagnostic, so it defaults to doing nothing.
    def self.call(invoices:, accounts:, bank:, notice:, on: Date.today, listener: NullListener.new)
      new(invoices: invoices, accounts: accounts, bank: bank, notice: notice, on: on, listener: listener).call
    end

    def initialize(invoices:, accounts:, bank:, notice:, on:, listener:)
      @bank     = bank
      @on       = on
      @listener = listener
      @run      = Run.new
      @applied_transaction_ids = Set.new

      # An invoice listed twice is still only one invoice: handle it once and
      # report the repeat, before anything can be charged or sent. (Business rule R8.)
      seen = Set.new
      @repeats, unique = invoices.partition { |record| !seen.add?(record.number) }

      customers = accounts.to_h { |account| [account.id, cast_customer(account, notice)] }
      @uncastable, castable = unique.partition { |record| customers[record.account_id].nil? }
      @invoices = castable.map { |record| cast_invoice(record, customers.fetch(record.account_id)) }
    end

    # To assess late fees:
    #   1. report any invoice whose account we cannot find, or that is listed more
    #      than once; carry on with the rest
    #   2. send any late-fee notice from an earlier run that did not go out
    #   3. pick the invoices due a late fee today
    #   4. check the bank for every customer with such an invoice, before
    #      changing anything; if the bank is down, charge nobody tonight
    #   5. for each due invoice: if a cleared deposit already covers it, mark it
    #      paid; otherwise add a late fee and tell whoever handles the customer's
    #      billing. One bad invoice does not stop the others
    #   6. sanity-check the results and report the summary
    def call
      @repeats.each { |record| not_processed(record.number, 'listed more than once in this run') }
      @uncastable.each { |record| not_processed(record.number, "no account #{record.account_id}") }

      send_earlier_notices

      due = @invoices.select { |invoice| invoice.due_for_late_fee?(@on) }

      begin
        bank_check = CheckBank.call(invoices: due, bank: @bank)
      rescue BankUnavailable => e
        # Without the bank we can't tell who has already paid, so nobody is
        # charged or marked paid tonight. (Business rule R5.)
        @run.bank_unavailable = e.message
        @listener.bank_unavailable(e.message)
        return finish
      end

      due.each { |invoice| settle(invoice, bank_check) }

      finish
    end

    def send_earlier_notices
      # A customer charged a fee must hear about it. A notice that failed is sent
      # again on every run until it goes out. (Business rule R9.)
      @invoices.each do |invoice|
        invoice.unsent_late_fees.each do |fee|
          next unless tell_customer(invoice, fee)

          @run.earlier_notices_sent << invoice.number
          @listener.earlier_notice_sent(invoice.unwrap, fee.amount_cents)
        end
      end
    end
    private :send_earlier_notices

    def settle(invoice, bank_check)
      deposit = invoice.covering_deposit(bank_check.deposits_for(invoice.customer),
                                         already_applied: @applied_transaction_ids)
      if deposit
        invoice.mark_paid!
        @applied_transaction_ids << deposit.transaction_id
        @run.found_paid << invoice.number
        @listener.invoice_found_paid(invoice.unwrap)
      else
        fee = invoice.add_late_fee!(invoice.late_fee_cents, on: @on)
        @run.late_fees << [invoice.number, fee.amount_cents]
        @listener.late_fee_added(invoice.unwrap, fee.amount_cents)
        tell_customer(invoice, fee)
      end
    rescue RecordProblem => e
      # One invoice's problem is reported and the others carry on. (Business rule R7.)
      not_processed(invoice.number, e.message)
    end
    private :settle

    def tell_customer(invoice, fee)
      invoice.customer.notify_of_late_fee!(invoice, fee.amount_cents)
    rescue NoticeFailed => e
      # The fee stands; the notice stays unsent and is retried next run (R9).
      @run.warnings << [invoice.number, "late fee notice failed, will retry next run: #{e.message}"]
      @listener.late_fee_notice_failed(invoice.unwrap, e.message)
      false
    else
      invoice.mark_notice_sent!(fee)
      true
    end
    private :tell_customer

    def not_processed(number, reason)
      @run.not_processed << [number, reason]
      @listener.invoice_not_processed(number, reason)
    end
    private :not_processed

    def finish
      @run.check_totals!
      @listener.run_finished(@run)
      @run # control our return value
    end
    private :finish

    def cast_customer(account, notice)
      if account.billed_through_reseller
        ResellerCustomer.new(account, notice: notice)
      else
        DirectCustomer.new(account, notice: notice)
      end
    end
    private :cast_customer

    def cast_invoice(record, customer)
      if customer.on_payment_plan?
        PaymentPlanInvoice.new(record, customer: customer)
      else
        ChargeableInvoice.new(record, customer: customer)
      end
    end
    private :cast_invoice
  end
end
