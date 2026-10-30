import 'package:hex_dci_example/features/invoice_account/billable_accounts.dart';
import 'package:hex_dci_example/features/invoice_account/build_invoice.dart';
import 'package:hex_dci_example/features/invoice_account/draft_invoice.dart';
import 'package:hex_dci_example/features/invoice_account/invoice_account.dart';
import 'package:hex_dci_example/ports/notifier.dart';
import 'package:hex_dci_example/records/records.dart';
import 'package:test/test.dart';

class RecordingListener implements InvoiceAccountListener {
  final events = <(String, Object)>[];

  @override
  void nothingToInvoice(Account account) => events.add(('nothingToInvoice', account));
  @override
  void invoiceFinalized(InvoiceRecord invoice) => events.add(('invoiceFinalized', invoice));
  @override
  void invoiceHeld(InvoiceRecord invoice) => events.add(('invoiceHeld', invoice));
}

class FakeNotifier implements Notifier {
  final sent = <({List<Contact> recipients, InvoiceRecord invoice})>[];

  @override
  Future<void> invoiceReady({required List<Contact> recipients, required InvoiceRecord invoice}) async =>
      sent.add((recipients: recipients, invoice: invoice));
}

Account account({
  String? companyEmail,
  List<Contact> billingContacts = const [],
  List<Contact> contacts = const [],
  bool billedThroughReseller = false,
  List<int> pastInvoiceTotalsCents = const [],
}) =>
    Account(
      id: 7,
      name: 'Example Coffee',
      companyEmail: companyEmail,
      billingContacts: billingContacts,
      contacts: contacts,
      billedThroughReseller: billedThroughReseller,
      pastInvoiceTotalsCents: pastInvoiceTotalsCents,
    );

Contact contact(String name) => Contact(name: name, email: '${name.toLowerCase()}@example.test');

Charge charge(int amountCents, [String description = 'Fee']) =>
    Charge(description: description, amountCents: amountCents);

DraftInvoice invoiceTotaling(int cents) => DraftInvoice.newFor(1)..addLine(description: 'Fee', amountCents: cents);

const steadyHistory = [10000, 10000, 10000];

void main() {
  group('DraftInvoice', () {
    // (description, past totals, this total, in bounds?)
    const inBoundsRules = [
      ('no history', <int>[], 1000000, true),
      ('fewer than three past invoices', [1000, 1000], 1000000, true),
      ('within \$5.00 of the average', steadyHistory, 10500, true),
      ('just over \$5.00 with no variation', steadyHistory, 10501, false),
      ('within three standard deviations', [10000, 20000, 30000], 40000, true),
      ('beyond three standard deviations', [10000, 20000, 30000], 50000, false),
      ('far below the average counts too', steadyHistory, 1000, false),
    ];
    for (final (description, past, total, expected) in inBoundsRules) {
      test('in bounds: $description', () => expect(invoiceTotaling(total).inBounds(past), expected));
    }

    test('hold marks held and saves', () async {
      final invoice = invoiceTotaling(1000);
      await invoice.hold();
      expect(invoice.unwrap().status, InvoiceStatus.held);
      expect(invoice.unwrap().saved, isTrue);
    });
  });

  group('BillableAccount recipients', () {
    List<Contact> recipientsFor(Account a) => ResellerBilledAccount(a).recipients;

    test('are the billing contacts when present', () {
      final billing = [contact('Pat')];
      expect(recipientsFor(account(billingContacts: billing, companyEmail: 'co@example.test')), billing);
    });

    test('fall back to the company email', () {
      expect(recipientsFor(account(companyEmail: 'co@example.test', contacts: [contact('Sam')])).map((r) => r.email),
          ['co@example.test']);
    });

    test('fall back to all contacts', () {
      final everyone = [contact('Sam'), contact('Lee')];
      expect(recipientsFor(account(contacts: everyone)), everyone);
    });
  });

  test('BuildInvoice dates, addresses, and adds a line per charge', () {
    final acct = DirectBilledAccount(account(companyEmail: 'co@example.test'), notifier: NullNotifier());
    final invoice = DraftInvoice.newFor(acct.id);
    final on = DateTime.utc(2026, 10, 1);

    BuildInvoice.call(invoice: invoice, account: acct, on: on, charges: [charge(2995, 'Monthly fee'), charge(7310, 'Processing')]);

    final record = invoice.unwrap();
    expect(record.invoiceDate, on);
    expect(record.recipients.map((r) => r.email), ['co@example.test']);
    expect(record.lines.map((l) => l.description), ['Monthly fee', 'Processing']);
    expect(record.totalCents, 10305);
  });

  group('InvoiceAccount', () {
    late RecordingListener listener;
    late FakeNotifier notifier;

    setUp(() {
      listener = RecordingListener();
      notifier = FakeNotifier();
    });

    Future<InvoiceRecord?> invoice(Account acct, List<Charge> charges) => InvoiceAccount.call(
        account: acct, charges: charges, notifier: notifier, on: DateTime.utc(2026, 10, 1), listener: listener);

    test('nothing to invoice without charges', () async {
      final acct = account();
      expect(await invoice(acct, []), isNull);
      expect(listener.events, [('nothingToInvoice', acct)]);
      expect(notifier.sent, isEmpty);
    });

    test('an in-bounds invoice is finalized and the account notified', () async {
      final result = await invoice(account(companyEmail: 'co@example.test', pastInvoiceTotalsCents: steadyHistory), [charge(10200)]);
      expect(result!.status, InvoiceStatus.finalized);
      expect(listener.events, [('invoiceFinalized', result)]);
      expect(notifier.sent, hasLength(1));
    });

    test('a reseller-billed account is finalized but not notified', () async {
      final result = await invoice(account(billedThroughReseller: true, pastInvoiceTotalsCents: steadyHistory), [charge(10200)]);
      expect(result!.status, InvoiceStatus.finalized);
      expect(notifier.sent, isEmpty);
    });

    test('an out-of-bounds invoice is held and nobody is notified', () async {
      final result = await invoice(account(companyEmail: 'co@example.test', pastInvoiceTotalsCents: steadyHistory), [charge(25000)]);
      expect(result!.status, InvoiceStatus.held);
      expect(listener.events, [('invoiceHeld', result)]);
      expect(notifier.sent, isEmpty);
    });

    test('works with the default null listener', () async {
      final result = await InvoiceAccount.call(account: account(companyEmail: 'co@example.test'), charges: [charge(1000)], notifier: notifier);
      expect(result!.status, InvoiceStatus.finalized);
    });
  });
}
