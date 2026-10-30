# Entry point (driving adapter): the nightly job.
#
# Scope: every open invoice. In a real app these would come from the database
# (`InvoiceRecord.where(status: 'open')`). Prints only the summary.
require_relative '../features/assess_late_fees'
require_relative 'demo_data'

run = AssessLateFees::Context.call(invoices: DemoData.open_invoices, accounts: DemoData::ACCOUNTS,
                                   bank: DemoData::Bank.new, notice: AssessLateFees::StdoutLateFeeNotice.new,
                                   on: DemoData::TODAY, listener: AssessLateFees::SummaryListener.new)

exit(run.bank_unavailable ? 2 : 0)
