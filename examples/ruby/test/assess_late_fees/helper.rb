require 'minitest/autorun'
require 'date'
require_relative '../../features/assess_late_fees'

module LateFeeFakes
  TODAY = Date.new(2026, 10, 29)

  # Answers with the bank's own record format. Never a null object: tests say
  # exactly what the bank returns, or that it is down.
  class FakeBank
    attr_reader :asked_about

    def initialize(deposits = {}, down: false)
      @deposits = deposits
      @down = down
      @asked_about = []
    end

    def recent_deposits(bank_account_number)
      @asked_about << bank_account_number
      raise BankUnavailable, 'bank is down' if @down

      @deposits.fetch(bank_account_number, [])
    end
  end

  class FakeNotice
    attr_reader :sent
    attr_accessor :failing

    def initialize(failing: false)
      @failing = failing
      @sent = []
    end

    def late_fee_added(to:, invoice:, fee_cents:)
      raise AssessLateFees::NoticeFailed, 'mail server refused' if @failing

      @sent << { to: to, number: invoice.number, fee_cents: fee_cents }
    end
  end

  class RecordingListener < AssessLateFees::NullListener
    attr_reader :events

    def initialize
      @events = []
    end

    %i[invoice_not_processed late_fee_added invoice_found_paid late_fee_notice_failed
       earlier_notice_sent bank_unavailable run_finished].each do |name|
      define_method(name) { |*args| @events << [name, *args] }
    end

    def names
      @events.map(&:first)
    end
  end

  def account(id: 1, **overrides)
    Account.new(**{ id: id, name: "Account #{id}", company_email: "ap#{id}@example.test",
                    bank_account_number: "acct-#{id}" }.merge(overrides))
  end

  def invoice(number: '2026-0412', account_id: 1, days_past_due: 45, balance_cents: 100_000, last_fee_days_ago: nil)
    record = InvoiceRecord.new(account_id: account_id, number: number, due_date: TODAY - days_past_due,
                               balance_cents: balance_cents, status: 'open')
    if last_fee_days_ago
      record.late_fees << LateFee.new(amount_cents: 500, assessed_on: TODAY - last_fee_days_ago, notice_sent: true)
    end
    record
  end

  def deposit(amt: '1000.00', memo: 'INV 2026-0412', sts: 'CLR', txn_id: 'T-1')
    { 'txn_id' => txn_id, 'amt' => amt, 'memo_txt' => memo, 'posted' => '20261027', 'sts' => sts }
  end
end
