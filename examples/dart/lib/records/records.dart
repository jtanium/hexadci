// Stand-ins for persistence-backed models (a Drift row, a Firestore document,
// a JSON-backed entity, etc.).
//
// They hold data and broadly useful accessors, and nothing specific to any one
// business operation. Operation-specific behavior lives in role classes inside
// each feature folder.

class Contact {
  final String name;
  final String email;

  const Contact({required this.name, required this.email});
}

class Charge {
  final String description;
  final int amountCents;

  const Charge({required this.description, required this.amountCents});
}

class Account {
  final int id;
  final String name;
  final String? companyEmail;
  final List<Contact> billingContacts;
  final List<Contact> contacts;
  final bool billedThroughReseller;
  final String? resellerEmail;
  final bool onPaymentPlan;
  final String? bankAccountNumber;
  final List<int> pastInvoiceTotalsCents;

  const Account({
    required this.id,
    required this.name,
    this.companyEmail,
    this.billingContacts = const [],
    this.contacts = const [],
    this.billedThroughReseller = false,
    this.resellerEmail,
    this.onPaymentPlan = false,
    this.bankAccountNumber,
    this.pastInvoiceTotalsCents = const [],
  });
}

class InvoiceLine {
  final String description;
  final int amountCents;

  const InvoiceLine({required this.description, required this.amountCents});
}

class LateFee {
  final int amountCents;
  final DateTime assessedOn;
  bool noticeSent;

  LateFee({required this.amountCents, required this.assessedOn, this.noticeSent = false});
}

enum InvoiceStatus { draft, open, held, finalized, paid }

class InvoiceRecord {
  final int accountId;
  String? number;
  DateTime? invoiceDate;
  DateTime? dueDate;
  List<Contact> recipients = [];
  final List<InvoiceLine> lines = [];
  int totalCents = 0;
  int balanceCents;
  final List<LateFee> lateFees = [];
  InvoiceStatus status;
  bool saved = false;

  InvoiceRecord(
    this.accountId, {
    this.number,
    this.dueDate,
    this.balanceCents = 0,
    this.status = InvoiceStatus.draft,
  });

  Future<void> save() async {
    saved = true;
  }
}
