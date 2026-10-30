# Entry point (driving adapter): Ops runs late fees for one account when a
# customer calls in. Same context and rules as the nightly job; narrower scope
# and a listener that narrates every step.
#
#   ruby bin/assess_late_fees_for_account.rb ACCOUNT_ID
require_relative '../features/assess_late_fees'
require_relative 'demo_data'

account = DemoData::ACCOUNTS.find { |a| a.id == ARGV.fetch(0, '0').to_i }
abort "No account #{ARGV[0].inspect}" unless account

run = AssessLateFees::Context.call(invoices: DemoData.open_invoices.select { |i| i.account_id == account.id },
                                   accounts: [account], bank: DemoData::Bank.new,
                                   notice: AssessLateFees::StdoutLateFeeNotice.new,
                                   on: DemoData::TODAY, listener: AssessLateFees::PrintingListener.new)

exit(run.bank_unavailable ? 2 : 0)
