require_relative 'helper'

class LateFeeCalculationTest < Minitest::Test
  include LateFeeFakes

  # [description, balance cents, fee cents]
  FEE_RULES = [
    ['1.5% of the balance',                  100_000, 1_500],
    ['never less than $5.00',                 20_000,   500],
    ['half a cent rounds up',                 50_100,   752],
    ['under half a cent rounds down',         50_033,   750]
  ].freeze

  def test_late_fee_amounts
    FEE_RULES.each do |description, balance, fee|
      role = AssessLateFees::ChargeableInvoice.new(invoice(balance_cents: balance), customer: nil)
      assert_equal fee, role.late_fee_cents, description
    end
  end

  def test_payment_plan_invoices_are_never_due
    role = AssessLateFees::PaymentPlanInvoice.new(invoice(days_past_due: 365), customer: nil)
    refute role.due_for_late_fee?(TODAY)
  end
end

class RetrieveDepositsTest < Minitest::Test
  include LateFeeFakes

  def deposits(*raw)
    AssessLateFees::RetrieveDeposits.call(bank: FakeBank.new({ 'acct-1' => raw }), bank_account_number: 'acct-1')
  end

  def test_translates_the_banks_fields_into_ours
    translated = deposits(deposit(amt: '125.5', memo: 'INV 7', sts: 'PND')).first

    assert_equal 12_550, translated.amount_cents
    assert_equal 'INV 7', translated.memo
    refute translated.cleared
  end

  def test_whole_dollar_amounts
    assert_equal 12_500, deposits(deposit(amt: '125')).first.amount_cents
  end

  def test_keeps_the_banks_transaction_id
    assert_equal 'T-42', deposits(deposit(txn_id: 'T-42')).first.transaction_id
  end

  def test_refuses_what_it_cannot_read
    [deposit(amt: '12.345'), deposit(amt: '-5.00'), deposit(sts: 'XYZ'), deposit(txn_id: '')].each do |raw|
      assert_raises(AssessLateFees::UnrecognizedDeposit, raw.inspect) { deposits(raw) }
    end
  end
end

class RunTest < Minitest::Test
  def test_impossible_runs_raise
    run = AssessLateFees::Run.new
    run.bank_unavailable = 'down'
    run.late_fees << ['A-1', 1_500]
    assert_raises(AssessLateFees::ImpossibleRun) { run.check_totals! }

    run = AssessLateFees::Run.new
    run.late_fees << ['A-1', 100]
    assert_raises(AssessLateFees::ImpossibleRun) { run.check_totals! }

    run = AssessLateFees::Run.new
    run.late_fees << ['A-1', 1_500]
    run.found_paid << 'A-1'
    assert_raises(AssessLateFees::ImpossibleRun) { run.check_totals! }
  end

  def test_a_reported_repeat_is_not_an_impossible_run
    run = AssessLateFees::Run.new
    run.late_fees << ['A-1', 1_500]
    run.not_processed << ['A-1', 'listed more than once in this run']
    run.check_totals!
  end
end
