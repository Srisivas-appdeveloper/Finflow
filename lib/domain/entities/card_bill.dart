import 'package:meta/meta.dart';

import 'money.dart';

enum BillStatus {
  unpaid('Unpaid'),
  minimumPaid('Minimum paid'),
  partiallyPaid('Partly paid'),
  paid('Paid');

  const BillStatus(this.label);
  final String label;
}

/// One credit card statement, entered from the bank's statement or app.
///
/// [totalDue] is the statement balance on the statement date. It is
/// deliberately separate from the card's live outstanding balance.
@immutable
class CardBill {
  const CardBill({
    required this.id,
    required this.cardId,
    required this.statementDate,
    required this.dueDate,
    required this.totalDue,
    required this.minimumDue,
    this.paid = const Money.zero(),
  });

  final String id;
  final String cardId;
  final DateTime statementDate;
  final DateTime dueDate;
  final Money totalDue;
  final Money minimumDue;

  /// Sum of payments recorded against this bill. Derived from linked
  /// card-payment transactions, never stored separately.
  final Money paid;

  Money get remaining {
    final r = totalDue - paid;
    return r.isNegative ? Money.zero(currencyCode: r.currencyCode) : r;
  }

  BillStatus get status {
    if (!totalDue.isPositive || paid.minor >= totalDue.minor) {
      return BillStatus.paid;
    }
    if (paid.isZero) return BillStatus.unpaid;
    if (paid.minor >= minimumDue.minor) return BillStatus.minimumPaid;
    return BillStatus.partiallyPaid;
  }

  bool get isSettled => status == BillStatus.paid;

  /// Past the due date without at least the minimum paid. Paying the
  /// minimum on time avoids being late (interest still applies to the rest).
  /// When no minimum was entered, the full amount is required.
  bool isOverdue(DateTime now) {
    final required = minimumDue.isPositive ? minimumDue : totalDue;
    return paid.minor < required.minor &&
        DateTime(now.year, now.month, now.day).isAfter(dueDate);
  }

  /// Whole days until the due date (negative when overdue).
  int daysUntilDue(DateTime now) => DateTime(
    dueDate.year,
    dueDate.month,
    dueDate.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;

  CardBill copyWith({
    DateTime? statementDate,
    DateTime? dueDate,
    Money? totalDue,
    Money? minimumDue,
    Money? paid,
  }) {
    return CardBill(
      id: id,
      cardId: cardId,
      statementDate: statementDate ?? this.statementDate,
      dueDate: dueDate ?? this.dueDate,
      totalDue: totalDue ?? this.totalDue,
      minimumDue: minimumDue ?? this.minimumDue,
      paid: paid ?? this.paid,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CardBill &&
      other.id == id &&
      other.cardId == cardId &&
      other.statementDate == statementDate &&
      other.dueDate == dueDate &&
      other.totalDue == totalDue &&
      other.minimumDue == minimumDue &&
      other.paid == paid;

  @override
  int get hashCode => Object.hash(
    id,
    cardId,
    statementDate,
    dueDate,
    totalDue,
    minimumDue,
    paid,
  );
}
