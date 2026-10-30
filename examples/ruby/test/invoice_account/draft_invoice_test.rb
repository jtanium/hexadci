require_relative '../test_helper'

class DraftInvoiceTest < Minitest::Test
  def invoice_totaling(cents)
    invoice = InvoiceAccount::DraftInvoice.new(InvoiceRecord.new(account_id: 1))
    invoice.add_line!(description: 'Fee', amount_cents: cents)
    invoice
  end

  # [description, past totals, this total, in bounds?]
  IN_BOUNDS_RULES = [
    ['no history',                           [],                     1_000_000, true],
    ['fewer than three past invoices',       [1_000, 1_000],         1_000_000, true],
    ['within $5.00 of the average',          [10_000, 10_000, 10_000], 10_500, true],
    ['just over $5.00 with no variation',    [10_000, 10_000, 10_000], 10_501, false],
    ['within three standard deviations',     [10_000, 20_000, 30_000], 40_000, true],
    ['beyond three standard deviations',     [10_000, 20_000, 30_000], 50_000, false],
    ['far below the average counts too',     [10_000, 10_000, 10_000],  1_000, false]
  ].freeze

  IN_BOUNDS_RULES.each do |description, past, total, expected|
    define_method("test_in_bounds_#{description.tr(' $.', '___')}") do
      assert_equal expected, invoice_totaling(total).in_bounds?(past), description
    end
  end

  def test_add_line_accumulates_the_total
    invoice = invoice_totaling(1_000)
    invoice.add_line!(description: 'Another fee', amount_cents: 250)
    assert_equal 1_250, invoice.total_cents
    assert_equal 2, invoice.unwrap.lines.length
  end

  def test_hold_marks_held_and_saves
    invoice = invoice_totaling(1_000)
    invoice.hold!
    assert_equal 'held', invoice.unwrap.status
    assert invoice.unwrap.saved?
  end

  def test_finalize_marks_final_and_saves
    invoice = invoice_totaling(1_000)
    invoice.finalize!
    assert_equal 'final', invoice.unwrap.status
    assert invoice.unwrap.saved?
  end
end
