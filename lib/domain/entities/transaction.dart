import 'package:meta/meta.dart';

import 'money.dart';
import 'transaction_category.dart';

enum TransactionDirection {
  /// Money leaving the user (a payment or purchase).
  debit,

  /// Money arriving (salary, refund).
  credit,
}

enum TransactionStatus {
  completed('Completed'),
  pending('Pending'),
  failed('Failed');

  const TransactionStatus(this.label);
  final String label;
}

enum PaymentMethod {
  upi('UPI'),
  card('Card'),
  bankTransfer('Bank transfer'),
  cash('Cash'),
  wallet('Wallet'),

  /// Someone in a split group paid; the user owes them their share.
  paidByOther('Paid by someone else');

  const PaymentMethod(this.label);
  final String label;

  /// Methods the user picks when entering a payment. [paidByOther] is only
  /// set by splits.
  static List<PaymentMethod> get selectable =>
      values.where((m) => m != paidByOther).toList();
}

/// A single money movement recorded in FinFlow.
@immutable
class Transaction {
  const Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.direction,
    required this.category,
    required this.status,
    required this.occurredAt,
    required this.paymentMethod,
    this.reference,
    this.note,
    this.billId,
    this.share,
    this.splitId,
  });

  final String id;

  /// Payee or payer name.
  final String title;

  /// Unsigned amount. See [signedAmount].
  final Money amount;
  final TransactionDirection direction;
  final TransactionCategory category;
  final TransactionStatus status;
  final DateTime occurredAt;
  final PaymentMethod paymentMethod;
  final String? reference;
  final String? note;

  /// For card bill payments: the bill this payment settles.
  final String? billId;

  /// For a spend split with others: the user's own part of [amount]. Totals
  /// count this instead of [amount]; the rest is owed back by the group.
  final Money? share;

  /// The split expense or settlement this transaction belongs to.
  final String? splitId;

  bool get isCredit => direction == TransactionDirection.credit;
  bool get isDebit => direction == TransactionDirection.debit;

  /// Positive for credits, negative for debits.
  Money get signedAmount => isCredit ? amount : -amount;

  /// What this transaction cost or brought the user: [share] for split
  /// spends, otherwise [amount].
  Money get ownAmount => share ?? amount;

  bool get isSplit => splitId != null;

  /// Whether this transaction should count towards totals. Failed payments
  /// never moved money.
  bool get affectsBalance => status != TransactionStatus.failed;

  Transaction copyWith({
    String? id,
    String? title,
    Money? amount,
    TransactionDirection? direction,
    TransactionCategory? category,
    TransactionStatus? status,
    DateTime? occurredAt,
    PaymentMethod? paymentMethod,
    String? note,
    bool clearNote = false,
    Money? share,
    bool clearShare = false,
    bool clearSplit = false,
  }) {
    return Transaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      direction: direction ?? this.direction,
      category: category ?? this.category,
      status: status ?? this.status,
      occurredAt: occurredAt ?? this.occurredAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      reference: reference,
      note: clearNote ? null : (note ?? this.note),
      billId: billId,
      share: clearShare ? null : (share ?? this.share),
      splitId: clearSplit ? null : splitId,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Transaction &&
      other.id == id &&
      other.category == category &&
      other.note == note &&
      other.status == status &&
      other.title == title &&
      other.amount == amount &&
      other.direction == direction &&
      other.occurredAt == occurredAt &&
      other.paymentMethod == paymentMethod &&
      other.share == share &&
      other.splitId == splitId;

  @override
  int get hashCode => Object.hash(
    id,
    category,
    note,
    status,
    title,
    amount,
    direction,
    occurredAt,
    paymentMethod,
    share,
    splitId,
  );
}
