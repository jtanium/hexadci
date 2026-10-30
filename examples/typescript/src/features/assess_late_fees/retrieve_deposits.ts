import type { Bank, RawDeposit } from "../../ports/bank.ts";
import { UnrecognizedDeposit } from "./errors.ts";

export interface Deposit {
  transactionId: string; // the bank's ID: the same transaction always has the same ID
  amountCents: number;
  memo: string;
  cleared: boolean;
}

const CLEARED: Record<string, boolean> = { CLR: true, PND: false };
const DOLLARS = /^(\d+)(?:\.(\d{1,2}))?$/;

/**
 * This step is the boundary between us and the bank's deposits API. Its only
 * job is translation: the bank's field names and codes ("txn_id", "amt",
 * "memo_txt", "sts") in, our Deposit out. It keeps the bank's transaction ID,
 * because which transaction paid which invoice is a business question (R4).
 * Whether a deposit counts as payment is decided by the invoice role, not here.
 */
export class RetrieveDeposits {
  private readonly bank: Bank;
  private readonly bankAccountNumber: string;

  static call(args: { bank: Bank; bankAccountNumber: string }): Deposit[] {
    return new RetrieveDeposits(args).call();
  }

  constructor({ bank, bankAccountNumber }: { bank: Bank; bankAccountNumber: string }) {
    this.bank = bank;
    this.bankAccountNumber = bankAccountNumber;
  }

  call(): Deposit[] {
    return this.bank.recentDeposits(this.bankAccountNumber).map((raw) => this.translate(raw));
  }

  private translate(raw: RawDeposit): Deposit {
    const transactionId = String(raw.txn_id ?? "");
    const amount = DOLLARS.exec(String(raw.amt ?? ""));
    const status = String(raw.sts ?? "");
    if (!transactionId.trim() || !amount || !(status in CLEARED)) {
      throw new UnrecognizedDeposit(
        `RetrieveDeposits.translate could not read deposit ${JSON.stringify(raw)} ` +
          `for bank account ending ${this.bankAccountNumber.slice(-4)}`,
      );
    }

    const cents = (amount[2] ?? "").padEnd(2, "0");
    return {
      transactionId,
      amountCents: Number(amount[1]) * 100 + Number(cents),
      memo: String(raw.memo_txt ?? ""),
      cleared: CLEARED[status],
    };
  }
}
