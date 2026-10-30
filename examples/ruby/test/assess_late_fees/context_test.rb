require_relative 'helper'

class AssessLateFeesContextTest < Minitest::Test
  include LateFeeFakes

  def setup
    @bank = FakeBank.new
    @notice = FakeNotice.new
    @listener = RecordingListener.new
  end

  def assess(invoices, accounts = [account])
    AssessLateFees::Context.call(invoices: invoices, accounts: accounts, bank: @bank, notice: @notice,
                                 on: TODAY, listener: @listener)
  end

  # [description, invoice attributes, account attributes, charged?]
  WHO_IS_CHARGED = [
    ['more than 30 days past due',          { days_past_due: 31 },                         {},                        true],
    ['exactly 30 days past due',            { days_past_due: 30 },                         {},                        false],
    ['last fee only 10 days ago',           { days_past_due: 90, last_fee_days_ago: 10 },  {},                        false],
    ['last fee 30 days ago',                { days_past_due: 90, last_fee_days_ago: 30 },  {},                        true],
    ['customer on a payment plan',          { days_past_due: 90 },                         { on_payment_plan: true }, false]
  ].freeze

  def test_who_is_charged
    WHO_IS_CHARGED.each do |description, invoice_attrs, account_attrs, charged|
      setup
      run = assess([invoice(**invoice_attrs)], [account(**account_attrs)])
      assert_equal (charged ? 1 : 0), run.late_fees.length, description
    end
  end

  # [description, deposits at the bank, found paid?]
  BANK_CASES = [
    ['cleared deposit covering the balance',      [{ amt: '1000.00' }],                 true],
    ['cleared deposit over the balance',          [{ amt: '1500.00' }],                 true],
    ['cleared deposit short of the balance',      [{ amt: '999.99' }],                  false],
    ['pending deposit covering the balance',      [{ sts: 'PND' }],                     false],
    ['deposit for another invoice',               [{ memo: 'INV 2026-0999' }],          false],
    ['memo with a longer number containing ours', [{ memo: 'INV 2026-04120' }],         false]
  ].freeze

  def test_bank_check_before_charging
    BANK_CASES.each do |description, deposits, paid|
      setup
      @bank = FakeBank.new({ 'acct-1' => deposits.map { |attrs| deposit(**attrs) } })
      record = invoice
      run = assess([record])

      assert_equal (paid ? ['2026-0412'] : []), run.found_paid, description
      assert_equal (paid ? 'paid' : 'open'), record.status, description
      assert_equal (paid ? 0 : 1), run.late_fees.length, description
    end
  end

  def test_late_fee_is_added_and_the_billing_contact_told
    record = invoice(balance_cents: 100_000)
    run = assess([record])

    assert_equal [['2026-0412', 1_500]], run.late_fees
    assert_equal 101_500, record.balance_cents
    assert_equal [{ to: 'ap1@example.test', number: '2026-0412', fee_cents: 1_500 }], @notice.sent
  end

  def test_reseller_is_told_instead_of_the_customer
    assess([invoice], [account(billed_through_reseller: true, reseller_email: 'billing@reseller.test')])
    assert_equal ['billing@reseller.test'], @notice.sent.map { |n| n[:to] }
  end

  def test_bank_down_means_nobody_is_charged_or_marked_paid
    @bank = FakeBank.new(down: true)
    records = [invoice(number: 'A-1'), invoice(number: 'B-2', account_id: 2)]

    run = assess(records, [account(id: 1), account(id: 2)])

    assert_equal 'bank is down', run.bank_unavailable
    assert_empty run.late_fees
    assert(records.all? { |r| r.status == 'open' && r.late_fees.empty? })
    assert_empty @notice.sent
    assert_equal %i[bank_unavailable run_finished], @listener.names
  end

  def test_payment_plan_customers_are_never_checked_at_the_bank
    @bank = FakeBank.new(down: true)
    run = assess([invoice(days_past_due: 90)], [account(on_payment_plan: true)])

    assert_empty @bank.asked_about
    assert_nil run.bank_unavailable
  end

  def test_unreadable_deposit_stops_that_customer_only
    @bank = FakeBank.new({ 'acct-1' => [deposit(amt: 'twelve')], 'acct-2' => [] })
    run = assess([invoice(number: 'A-1'), invoice(number: 'B-2', account_id: 2)], [account(id: 1), account(id: 2)])

    assert_equal ['A-1'], run.not_processed.map(&:first)
    assert_match(/could not read deposit/, run.not_processed.first.last)
    assert_equal ['B-2'], run.late_fees.map(&:first)
  end

  def test_failed_notice_is_a_warning_and_the_fee_stands
    @notice = FakeNotice.new(failing: true)
    record = invoice
    run = assess([record])

    assert_equal 1, record.late_fees.length
    assert_equal ['2026-0412'], run.warnings.map(&:first)
    assert_includes @listener.names, :late_fee_notice_failed
  end

  def test_invoice_without_an_account_is_reported_and_the_rest_continue
    run = assess([invoice(number: 'ORPHAN', account_id: 99), invoice(number: 'A-1')])

    assert_equal [['ORPHAN', 'no account 99']], run.not_processed
    assert_equal ['A-1'], run.late_fees.map(&:first)
  end

  def test_one_deposit_pays_one_invoice
    @bank = FakeBank.new({ 'acct-1' => [deposit(memo: '2026-0412 2026-0413')] })
    run = assess([invoice(number: '2026-0412'), invoice(number: '2026-0413')])

    assert_equal ['2026-0412'], run.found_paid
    assert_equal ['2026-0413'], run.late_fees.map(&:first)
  end

  def test_an_invoice_listed_twice_is_charged_and_notified_once
    record = invoice(balance_cents: 100_000)

    run = assess([record, record])

    assert_equal [['2026-0412', 1_500]], run.late_fees
    assert_equal 101_500, record.balance_cents
    assert_equal 1, @notice.sent.length
    assert_equal [['2026-0412', 'listed more than once in this run']], run.not_processed
  end

  def test_one_transaction_pays_one_invoice_even_when_customers_share_a_bank_account
    shared = 'shared-acct'
    @bank = FakeBank.new({ shared => [deposit(memo: '2026-0412 2026-0413', txn_id: 'T-77')] })
    records = [invoice(number: '2026-0412', account_id: 1), invoice(number: '2026-0413', account_id: 2)]

    run = assess(records, [account(id: 1, bank_account_number: shared), account(id: 2, bank_account_number: shared)])

    assert_equal ['2026-0412'], run.found_paid
    assert_equal ['2026-0413'], run.late_fees.map(&:first)
  end

  def test_a_failed_notice_is_sent_on_the_next_run
    record = invoice
    @notice = FakeNotice.new(failing: true)
    first = assess([record])
    assert_equal ['2026-0412'], first.warnings.map(&:first)
    refute record.late_fees.first.notice_sent

    @notice.failing = false
    @listener = RecordingListener.new
    second = assess([record])

    assert_empty second.late_fees # not charged again: the last fee was today
    assert_equal ['2026-0412'], second.earlier_notices_sent
    assert_equal [{ to: 'ap1@example.test', number: '2026-0412', fee_cents: 1_500 }], @notice.sent
    assert record.late_fees.first.notice_sent
    assert_includes @listener.names, :earlier_notice_sent
  end

  def test_a_notice_that_keeps_failing_is_reported_again_each_run
    record = invoice
    @notice = FakeNotice.new(failing: true)
    assess([record])

    second = assess([record])

    assert_equal ['2026-0412'], second.warnings.map(&:first)
    refute record.late_fees.first.notice_sent
  end

  def test_earlier_notices_go_out_even_when_the_bank_is_down
    record = invoice
    record.late_fees << LateFee.new(amount_cents: 1_500, assessed_on: TODAY) # notice never sent
    @bank = FakeBank.new(down: true)

    run = assess([record])

    assert_equal ['2026-0412'], run.earlier_notices_sent
    assert_empty run.late_fees
  end

  def test_programming_errors_are_not_hidden_as_record_problems
    broken = invoice
    broken.due_date = nil # a bug upstream, not bad customer data

    error = assert_raises(StandardError) { assess([broken]) }
    refute_kind_of AssessLateFees::RecordProblem, error
  end

  def test_returns_the_run_and_reports_it
    run = assess([invoice])

    assert_instance_of AssessLateFees::Run, run
    assert_equal [:run_finished, run], @listener.events.last
  end
end
