# Port: tells people that something is ready for them.
#
# Implementations decide how (email, SMS, a queue). Business operations only
# know the message they send.
class StdoutNotifier
  def initialize(out = $stdout)
    @out = out
  end

  def invoice_ready(recipients:, invoice:)
    @out.puts "Notified #{recipients.map(&:email).join(', ')} of invoice for account #{invoice.account_id}"
  end
end

class NullNotifier
  def invoice_ready(recipients:, invoice:)
    # no-op
  end
end
