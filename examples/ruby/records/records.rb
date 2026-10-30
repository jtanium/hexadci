# Stand-ins for persistence-backed models (ActiveRecord, Sequel, etc.).
#
# They hold data and broadly useful accessors, and nothing specific to any one
# business operation. Operation-specific behavior lives in role classes inside
# each feature folder.

Contact = Struct.new(:name, :email, keyword_init: true)

Charge = Struct.new(:description, :amount_cents, keyword_init: true)

Account = Struct.new(:id, :name, :company_email, :billing_contacts, :contacts,
                     :billed_through_reseller, :reseller_email, :on_payment_plan,
                     :bank_account_number, :past_invoice_totals_cents,
                     keyword_init: true)

LateFee = Struct.new(:amount_cents, :assessed_on, :notice_sent, keyword_init: true) do
  def initialize(amount_cents:, assessed_on:, notice_sent: false)
    super
  end
end

class InvoiceRecord
  attr_accessor :account_id, :number, :invoice_date, :due_date, :recipients, :lines,
                :total_cents, :balance_cents, :late_fees, :status

  def initialize(account_id:, number: nil, due_date: nil, balance_cents: 0, status: 'draft')
    @account_id    = account_id
    @number        = number
    @due_date      = due_date
    @balance_cents = balance_cents
    @status        = status
    @recipients    = []
    @lines         = []
    @late_fees     = []
    @total_cents   = 0
    @saved         = false
  end

  def save!
    @saved = true
  end

  def saved?
    @saved
  end
end
