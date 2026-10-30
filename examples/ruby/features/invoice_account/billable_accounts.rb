module InvoiceAccount
  # The account, in the role of "the one being invoiced".
  class BillableAccount
    def initialize(account)
      @account = account
    end

    def id
      @account.id
    end

    def past_invoice_totals_cents
      @account.past_invoice_totals_cents
    end

    # Invoices go to the people the account asked us to bill. If it named no
    # billing contacts, they go to the company's own email address; if there is
    # none, to everyone we have on file, so the invoice always reaches someone.
    # (Business rule R3.)
    def recipients
      [billing_contacts, company_address].find { |people| !people.empty? } || all_contacts
    end

    def unwrap
      @account
    end

    # How our records answer that question.

    def billing_contacts
      @account.billing_contacts
    end
    private :billing_contacts

    def company_address
      return [] unless @account.company_email

      [Contact.new(name: @account.name, email: @account.company_email)]
    end
    private :company_address

    def all_contacts
      @account.contacts
    end
    private :all_contacts
  end

  class DirectBilledAccount < BillableAccount
    def initialize(account, notifier:)
      super(account)
      @notifier = notifier
    end

    def notify_of_invoice!(invoice)
      @notifier.invoice_ready(recipients: recipients, invoice: invoice.unwrap)
    end
  end

  class ResellerBilledAccount < BillableAccount
    # The reseller sends this account its invoices and owns the relationship,
    # so we never contact the account directly. (Business rule R6.)
    def notify_of_invoice!(invoice)
      # no-op
    end
  end
end
