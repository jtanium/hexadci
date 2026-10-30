require_relative '../test_helper'

class BillableAccountsTest < Minitest::Test
  include Factories

  def recipients_for(account)
    InvoiceAccount::BillableAccount.new(account).recipients
  end

  def test_recipients_are_billing_contacts_when_present
    billing = [contact('Pat')]
    assert_equal billing, recipients_for(account(billing_contacts: billing, company_email: 'co@example.test',
                                                 contacts: [contact('Sam')]))
  end

  def test_recipients_fall_back_to_company_email
    recipients = recipients_for(account(company_email: 'co@example.test', contacts: [contact('Sam')]))
    assert_equal ['co@example.test'], recipients.map(&:email)
  end

  def test_recipients_fall_back_to_all_contacts
    everyone = [contact('Sam'), contact('Lee')]
    assert_equal everyone, recipients_for(account(contacts: everyone))
  end

  def test_direct_billed_account_notifies_its_recipients
    notifier = FakeNotifier.new
    role = InvoiceAccount::DirectBilledAccount.new(account(company_email: 'co@example.test'), notifier: notifier)
    invoice = InvoiceAccount::DraftInvoice.new(InvoiceRecord.new(account_id: 7))

    role.notify_of_invoice!(invoice)

    assert_equal 1, notifier.sent.length
    assert_equal ['co@example.test'], notifier.sent.first[:recipients].map(&:email)
    assert_same invoice.unwrap, notifier.sent.first[:invoice]
  end

  def test_reseller_billed_account_is_never_notified
    role = InvoiceAccount::ResellerBilledAccount.new(account(company_email: 'co@example.test'))
    assert_nil role.notify_of_invoice!(InvoiceAccount::DraftInvoice.new(InvoiceRecord.new(account_id: 7)))
  end
end
