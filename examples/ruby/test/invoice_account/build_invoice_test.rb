require_relative '../test_helper'

class BuildInvoiceTest < Minitest::Test
  include Factories

  def test_dates_addresses_and_adds_a_line_per_charge
    account = InvoiceAccount::BillableAccount.new(account(company_email: 'co@example.test'))
    invoice = InvoiceAccount::DraftInvoice.new_for(account)
    on = Date.new(2026, 10, 1)

    InvoiceAccount::BuildInvoice.call(invoice: invoice, account: account, on: on,
                                      charges: [charge(2_995, 'Monthly fee'), charge(7_310, 'Processing')])

    record = invoice.unwrap
    assert_equal on, record.invoice_date
    assert_equal ['co@example.test'], record.recipients.map(&:email)
    assert_equal ['Monthly fee', 'Processing'], record.lines.map { |l| l[:description] }
    assert_equal 10_305, record.total_cents
  end
end
