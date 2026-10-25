import 'package:meta/meta.dart';

import 'money.dart';

/// An instalment plan (EMI) entered by the user, usually a credit card
/// purchase converted to monthly instalments.
///
/// Instalments are billed on the card statement, so they are tracked here
/// as a schedule only. They are not added as spending: the original
/// purchase was counted once when it was made, which avoids double counting.
@immutable
class EmiPlan {
  const EmiPlan({
    required this.id,
    required this.title,
    required this.principal,
    required this.instalment,
    required this.tenureMonths,
    required this.firstDueDate,
    this.cardId,
    this.annualInterestRate,
    this.processingFee,
    this.closedOn,
  });

  final String id;
  final String title;

  /// Card the EMI is billed to, if any.
  final String? cardId;

  /// Original purchase or loan amount.
  final Money principal;

  /// Monthly instalment amount.
  final Money instalment;
  final int tenureMonths;
  final DateTime firstDueDate;

  /// Annual interest rate in percent, if known.
  final double? annualInterestRate;
  final Money? processingFee;

  /// Set when the plan was closed early (foreclosed or cancelled).
  final DateTime? closedOn;

  bool get isClosed => closedOn != null;

  /// Due date of instalment [n] (0-based), clamped to the month's end so a
  /// plan starting on the 31st falls on the 30th or 28th in shorter months.
  DateTime dueDateOf(int n) {
    final monthIndex = firstDueDate.month - 1 + n;
    final year = firstDueDate.year + monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = firstDueDate.day > lastDay ? lastDay : firstDueDate.day;
    return DateTime(year, month, day);
  }

  /// Instalments whose due date has arrived as of [now] (or as of the
  /// closing date for closed plans).
  int instalmentsDue(DateTime now) {
    final asOf = closedOn ?? now;
    final today = DateTime(asOf.year, asOf.month, asOf.day);
    var count = 0;
    for (var i = 0; i < tenureMonths; i++) {
      if (dueDateOf(i).isAfter(today)) break;
      count++;
    }
    return count;
  }

  int instalmentsRemaining(DateTime now) =>
      isClosed ? 0 : tenureMonths - instalmentsDue(now);

  /// Next instalment due after today, or null when finished or closed.
  DateTime? nextDueDate(DateTime now) {
    if (isClosed) return null;
    final due = instalmentsDue(now);
    return due >= tenureMonths ? null : dueDateOf(due);
  }

  /// Instalment amounts still to come.
  Money remainingAmount(DateTime now) => Money(
    instalment.minor * instalmentsRemaining(now),
    currencyCode: instalment.currencyCode,
  );

  /// Total of all instalments, plus any processing fee.
  Money get totalPayable => Money(
    instalment.minor * tenureMonths + (processingFee?.minor ?? 0),
    currencyCode: instalment.currencyCode,
  );

  /// Cost above the principal (interest and fees), if positive.
  Money get costOfCredit {
    final c = totalPayable - principal;
    return c.isNegative ? Money.zero(currencyCode: c.currencyCode) : c;
  }

  bool isComplete(DateTime now) => !isClosed && instalmentsRemaining(now) == 0;

  EmiPlan copyWith({
    String? title,
    String? cardId,
    bool clearCard = false,
    Money? principal,
    Money? instalment,
    int? tenureMonths,
    DateTime? firstDueDate,
    double? annualInterestRate,
    Money? processingFee,
    DateTime? closedOn,
    bool reopen = false,
  }) {
    return EmiPlan(
      id: id,
      title: title ?? this.title,
      cardId: clearCard ? null : (cardId ?? this.cardId),
      principal: principal ?? this.principal,
      instalment: instalment ?? this.instalment,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      firstDueDate: firstDueDate ?? this.firstDueDate,
      annualInterestRate: annualInterestRate ?? this.annualInterestRate,
      processingFee: processingFee ?? this.processingFee,
      closedOn: reopen ? null : (closedOn ?? this.closedOn),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EmiPlan &&
      other.id == id &&
      other.title == title &&
      other.cardId == cardId &&
      other.principal == principal &&
      other.instalment == instalment &&
      other.tenureMonths == tenureMonths &&
      other.firstDueDate == firstDueDate &&
      other.annualInterestRate == annualInterestRate &&
      other.processingFee == processingFee &&
      other.closedOn == closedOn;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    cardId,
    principal,
    instalment,
    tenureMonths,
    firstDueDate,
    annualInterestRate,
    processingFee,
    closedOn,
  );
}
