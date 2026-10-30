# Demo data standing in for the database and the bank, so the entry points run.
require 'date'

module DemoData
  TODAY = Date.new(2026, 10, 29)

  ACCOUNTS = [
    Account.new(id: 1, name: 'Example Coffee', company_email: 'ap@coffee.test', bank_account_number: '000111'),
    Account.new(id: 2, name: 'Resold Bakery', billed_through_reseller: true, reseller_email: 'billing@reseller.test',
                bank_account_number: '000222'),
    Account.new(id: 3, name: 'Planned Books', on_payment_plan: true, bank_account_number: '000333')
  ].freeze

  def self.open_invoices
    [InvoiceRecord.new(account_id: 1, number: '2026-0412', due_date: TODAY - 45, balance_cents: 100_000, status: 'open'),
     InvoiceRecord.new(account_id: 1, number: '2026-0415', due_date: TODAY - 40, balance_cents: 12_000, status: 'open'),
     InvoiceRecord.new(account_id: 2, number: '2026-0420', due_date: TODAY - 35, balance_cents: 20_000, status: 'open'),
     InvoiceRecord.new(account_id: 3, number: '2026-0431', due_date: TODAY - 90, balance_cents: 50_000, status: 'open')]
  end

  class Bank
    DEPOSITS = {
      '000111' => [{ 'txn_id' => 'T-1001', 'amt' => '120.00', 'memo_txt' => 'INV 2026-0415 thanks',
                    'posted' => '20261027', 'sts' => 'CLR' }]
    }.freeze

    def recent_deposits(bank_account_number)
      DEPOSITS.fetch(bank_account_number, [])
    end
  end
end
