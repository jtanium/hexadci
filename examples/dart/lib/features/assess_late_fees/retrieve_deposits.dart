import '../../ports/bank.dart';
import 'errors.dart';

class Deposit {
  final String transactionId; // the bank's ID: the same transaction always has the same ID
  final int amountCents;
  final String memo;
  final bool cleared;

  Deposit({required this.transactionId, required this.amountCents, required this.memo, required this.cleared});
}

const _cleared = {'CLR': true, 'PND': false};
final _dollars = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$');

/// This step is the boundary between us and the bank's deposits API. Its only
/// job is translation: the bank's field names and codes ('txn_id', 'amt',
/// 'memo_txt', 'sts') in, our Deposit out. It keeps the bank's transaction ID,
/// because which transaction paid which invoice is a business question (R4).
/// Whether a deposit counts as payment is decided by the invoice role, not here.
class RetrieveDeposits {
  final Bank _bank;
  final String _bankAccountNumber;

  static Future<List<Deposit>> call({required Bank bank, required String bankAccountNumber}) =>
      RetrieveDeposits._(bank, bankAccountNumber)._retrieve();

  RetrieveDeposits._(this._bank, this._bankAccountNumber);

  Future<List<Deposit>> _retrieve() async =>
      [for (final raw in await _bank.recentDeposits(_bankAccountNumber)) _translate(raw)];

  Deposit _translate(RawDeposit raw) {
    final transactionId = '${raw['txn_id'] ?? ''}';
    final amount = _dollars.firstMatch('${raw['amt'] ?? ''}');
    final cleared = _cleared['${raw['sts'] ?? ''}'];
    if (transactionId.trim().isEmpty || amount == null || cleared == null) {
      final ending = _bankAccountNumber.length > 4
          ? _bankAccountNumber.substring(_bankAccountNumber.length - 4)
          : _bankAccountNumber;
      throw UnrecognizedDeposit('RetrieveDeposits could not read deposit $raw for bank account ending $ending');
    }

    final cents = (amount.group(2) ?? '').padRight(2, '0');
    return Deposit(
      transactionId: transactionId,
      amountCents: int.parse(amount.group(1)!) * 100 + int.parse(cents),
      memo: '${raw['memo_txt'] ?? ''}',
      cleared: cleared,
    );
  }
}
