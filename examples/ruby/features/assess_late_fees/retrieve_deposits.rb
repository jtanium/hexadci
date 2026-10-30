module AssessLateFees
  # transaction_id is the bank's ID: the same transaction always has the same ID.
  Deposit = Struct.new(:transaction_id, :amount_cents, :memo, :cleared, keyword_init: true)

  # This step is the boundary between us and the bank's deposits API. Its only
  # job is translation: the bank's field names and codes ('txn_id', 'amt',
  # 'memo_txt', 'sts') in, our Deposit out. It keeps the bank's transaction ID,
  # because which transaction paid which invoice is a business question (R4).
  # Whether a deposit counts as payment is decided by the invoice role, not here.
  class RetrieveDeposits
    CLEARED = { 'CLR' => true, 'PND' => false }.freeze
    DOLLARS = /\A(\d+)(?:\.(\d{1,2}))?\z/

    def self.call(bank:, bank_account_number:)
      new(bank: bank, bank_account_number: bank_account_number).call
    end

    def initialize(bank:, bank_account_number:)
      @bank = bank
      @bank_account_number = bank_account_number
    end

    def call
      @bank.recent_deposits(@bank_account_number).map { |raw| translate(raw) }
    end

    def translate(raw)
      transaction_id = raw['txn_id'].to_s
      amount = DOLLARS.match(raw['amt'].to_s)
      unless !transaction_id.strip.empty? && amount && CLEARED.key?(raw['sts'])
        raise UnrecognizedDeposit,
              "#{self.class.name}#translate could not read deposit #{raw.inspect} " \
              "for bank account ending #{@bank_account_number.to_s[-4..]}"
      end

      Deposit.new(transaction_id: transaction_id,
                  amount_cents: amount[1].to_i * 100 + amount[2].to_s.ljust(2, '0').to_i,
                  memo: raw['memo_txt'].to_s,
                  cleared: CLEARED.fetch(raw['sts']))
    end
    private :translate
  end
end
