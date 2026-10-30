import { BankUnavailable } from "../../ports/bank.ts";
import type { Bank } from "../../ports/bank.ts";
import type { Account, InvoiceRecord, LateFee } from "../../records/index.ts";
import { CheckBank } from "./check_bank.ts";
import type { BankCheck } from "./check_bank.ts";
import { DirectCustomer, ResellerCustomer } from "./customers.ts";
import type { Customer } from "./customers.ts";
import { NoticeFailed, RecordProblem } from "./errors.ts";
import { ChargeableInvoice, PaymentPlanInvoice } from "./late_fee_invoices.ts";
import type { LateFeeInvoice } from "./late_fee_invoices.ts";
import type { LateFeeNotice } from "./late_fee_notice.ts";
import { NullListener } from "./listener.ts";
import type { Listener } from "./listener.ts";
import { Run } from "./run.ts";

export interface AssessLateFeesArgs {
  invoices: InvoiceRecord[];
  accounts: Account[];
  bank: Bank;
  notice: LateFeeNotice;
  on?: Date;
  listener?: Listener;
}

/**
 * Assess late fees on a set of open invoices. The nightly job passes every
 * open invoice; the single-account CLI passes one account's. Same rules.
 */
export class Context {
  private readonly bank: Bank;
  private readonly on: Date;
  private readonly listener: Listener;
  private readonly run = new Run();
  private readonly appliedTransactionIds = new Set<string>();
  private readonly repeats: InvoiceRecord[] = [];
  private readonly uncastable: InvoiceRecord[];
  private readonly invoices: LateFeeInvoice[];

  static call(args: AssessLateFeesArgs): Run {
    return new Context(args).call();
  }

  // `notice` has no default: telling the customer is required (R6).
  // The listener is diagnostic, so it defaults to doing nothing.
  constructor({ invoices, accounts, bank, notice, on = new Date(), listener = new NullListener() }: AssessLateFeesArgs) {
    this.bank = bank;
    this.on = on;
    this.listener = listener;

    // An invoice listed twice is still only one invoice: handle it once and
    // report the repeat, before anything can be charged or sent. (Business rule R8.)
    const seen = new Set<string | undefined>();
    const unique: InvoiceRecord[] = [];
    for (const record of invoices) {
      (seen.has(record.number) ? this.repeats : unique).push(record);
      seen.add(record.number);
    }

    const customers = new Map(accounts.map((account) => [account.id, Context.castCustomer(account, notice)]));
    this.uncastable = unique.filter((record) => !customers.has(record.accountId));
    this.invoices = unique.flatMap((record) => {
      const customer = customers.get(record.accountId);
      return customer ? [Context.castInvoice(record, customer)] : [];
    });
  }

  // To assess late fees:
  //   1. report any invoice whose account we cannot find, or that is listed more
  //      than once; carry on with the rest
  //   2. send any late-fee notice from an earlier run that did not go out
  //   3. pick the invoices due a late fee today
  //   4. check the bank for every customer with such an invoice, before
  //      changing anything; if the bank is down, charge nobody tonight
  //   5. for each due invoice: if a cleared deposit already covers it, mark it
  //      paid; otherwise add a late fee and tell whoever handles the customer's
  //      billing. One bad invoice does not stop the others
  //   6. sanity-check the results and report the summary
  call(): Run {
    for (const record of this.repeats) this.notProcessed(record.number ?? "", "listed more than once in this run");
    for (const record of this.uncastable) this.notProcessed(record.number ?? "", `no account ${record.accountId}`);

    this.sendEarlierNotices();

    const due = this.invoices.filter((invoice): invoice is ChargeableInvoice => invoice.dueForLateFee(this.on));

    let bankCheck: BankCheck;
    try {
      bankCheck = CheckBank.call({ invoices: due, bank: this.bank });
    } catch (error) {
      // Without the bank we can't tell who has already paid, so nobody is
      // charged or marked paid tonight. (Business rule R5.)
      if (!(error instanceof BankUnavailable)) throw error;
      this.run.bankUnavailable = error.message;
      this.listener.bankUnavailable(error.message);
      return this.finish();
    }

    for (const invoice of due) this.settle(invoice, bankCheck);

    return this.finish();
  }

  private sendEarlierNotices(): void {
    // A customer charged a fee must hear about it. A notice that failed is sent
    // again on every run until it goes out. (Business rule R9.)
    for (const invoice of this.invoices) {
      for (const fee of invoice.unsentLateFees()) {
        if (this.tellCustomer(invoice, fee)) {
          this.run.earlierNoticesSent.push(invoice.number);
          this.listener.earlierNoticeSent(invoice.unwrap(), fee.amountCents);
        }
      }
    }
  }

  private settle(invoice: ChargeableInvoice, bankCheck: BankCheck): void {
    try {
      const deposit = invoice.coveringDeposit(bankCheck.depositsFor(invoice.customer), this.appliedTransactionIds);
      if (deposit) {
        invoice.markPaid();
        this.appliedTransactionIds.add(deposit.transactionId);
        this.run.foundPaid.push(invoice.number);
        this.listener.invoiceFoundPaid(invoice.unwrap());
      } else {
        const fee = invoice.addLateFee(invoice.lateFeeCents, this.on);
        this.run.lateFees.push([invoice.number, fee.amountCents]);
        this.listener.lateFeeAdded(invoice.unwrap(), fee.amountCents);
        this.tellCustomer(invoice, fee);
      }
    } catch (error) {
      // One invoice's problem is reported and the others carry on. (Business rule R7.)
      if (!(error instanceof RecordProblem)) throw error;
      this.notProcessed(invoice.number, error.message);
    }
  }

  private tellCustomer(invoice: LateFeeInvoice, fee: LateFee): boolean {
    try {
      invoice.customer.notifyOfLateFee(invoice, fee.amountCents);
    } catch (error) {
      if (!(error instanceof NoticeFailed)) throw error;
      // The fee stands; the notice stays unsent and is retried next run (R9).
      this.run.warnings.push([invoice.number, `late fee notice failed, will retry next run: ${error.message}`]);
      this.listener.lateFeeNoticeFailed(invoice.unwrap(), error.message);
      return false;
    }
    invoice.markNoticeSent(fee);
    return true;
  }

  private notProcessed(number: string, reason: string): void {
    this.run.notProcessed.push([number, reason]);
    this.listener.invoiceNotProcessed(number, reason);
  }

  private finish(): Run {
    this.run.checkTotals();
    this.listener.runFinished(this.run);
    return this.run; // control our return value
  }

  private static castCustomer(account: Account, notice: LateFeeNotice): Customer {
    if (account.billedThroughReseller) return new ResellerCustomer(account, notice);
    return new DirectCustomer(account, notice);
  }

  private static castInvoice(record: InvoiceRecord, customer: Customer): LateFeeInvoice {
    if (customer.onPaymentPlan) return new PaymentPlanInvoice(record, customer);
    return new ChargeableInvoice(record, customer);
  }
}
