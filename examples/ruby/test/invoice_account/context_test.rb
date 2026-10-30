require_relative '../test_helper'

class InvoiceAccountContextTest < Minitest::Test
  include Factories

  def setup
    @listener = RecordingListener.new
    @notifier = FakeNotifier.new
  end

  def invoice(account, charges)
    InvoiceAccount::Context.call(account: account, charges: charges, notifier: @notifier,
                                 on: Date.new(2026, 10, 1), listener: @listener)
  end

  def steady_history
    [10_000, 10_000, 10_000]
  end

  def test_nothing_to_invoice_without_charges
    acct = account

    assert_nil invoice(acct, [])
    assert_equal [[:nothing_to_invoice, acct]], @listener.events
    assert_empty @notifier.sent
  end

  def test_in_bounds_invoice_is_finalized_and_the_account_notified
    result = invoice(account(company_email: 'co@example.test', past_invoice_totals_cents: steady_history),
                     [charge(10_200)])

    assert_equal 'final', result.status
    assert_equal [[:invoice_finalized, result]], @listener.events
    assert_equal 1, @notifier.sent.length
  end

  def test_reseller_billed_account_is_finalized_but_not_notified
    result = invoice(account(billed_through_reseller: true, past_invoice_totals_cents: steady_history),
                     [charge(10_200)])

    assert_equal 'final', result.status
    assert_equal [[:invoice_finalized, result]], @listener.events
    assert_empty @notifier.sent
  end

  def test_out_of_bounds_invoice_is_held_and_nobody_is_notified
    result = invoice(account(company_email: 'co@example.test', past_invoice_totals_cents: steady_history),
                     [charge(25_000)])

    assert_equal 'held', result.status
    assert_equal [[:invoice_held, result]], @listener.events
    assert_empty @notifier.sent
  end

  def test_returns_the_invoice_record_not_the_listener_result
    result = invoice(account(company_email: 'co@example.test'), [charge(1_000)])
    assert_instance_of InvoiceRecord, result
  end

  def test_works_with_the_default_null_listener
    result = InvoiceAccount::Context.call(account: account(company_email: 'co@example.test'),
                                          charges: [charge(1_000)], notifier: @notifier)
    assert_equal 'final', result.status
  end
end
