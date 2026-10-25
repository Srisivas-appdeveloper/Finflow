import 'package:meta/meta.dart';

import 'money.dart';

/// A credit card the user tracks manually.
///
/// The card's live outstanding balance cannot be known without a connection
/// to the issuer, so it is optional and always shown with the date it was
/// last updated.
@immutable
class CreditCard {
  const CreditCard({
    required this.id,
    required this.name,
    required this.issuer,
    required this.creditLimit,
    required this.statementDay,
    required this.dueDay,
    this.last4,
    this.currentOutstanding,
    this.outstandingUpdatedAt,
    this.styleIndex = 0,
  });

  final String id;

  /// User's nickname, e.g. "Travel card".
  final String name;

  /// Bank or issuer name as typed by the user.
  final String issuer;
  final String? last4;
  final Money creditLimit;

  /// Day of month the statement is generated (1-28).
  final int statementDay;

  /// Day of month payment is due (1-28).
  final int dueDay;

  /// Total outstanding (billed + unbilled) as last entered by the user.
  final Money? currentOutstanding;
  final DateTime? outstandingUpdatedAt;

  /// Visual style of the card face.
  final int styleIndex;

  /// Limit still available, if the outstanding balance is known.
  Money? get availableLimit =>
      currentOutstanding == null ? null : creditLimit - currentOutstanding!;

  /// Fraction of the limit in use (0..1+), if known.
  double? get utilisation => currentOutstanding == null || creditLimit.isZero
      ? null
      : currentOutstanding!.minor / creditLimit.minor;

  /// Outstanding figures older than this are flagged as possibly stale.
  static const staleAfter = Duration(days: 7);

  bool isOutstandingStale(DateTime now) =>
      outstandingUpdatedAt != null &&
      now.difference(outstandingUpdatedAt!) > staleAfter;

  CreditCard copyWith({
    String? name,
    String? issuer,
    String? last4,
    bool clearLast4 = false,
    Money? creditLimit,
    int? statementDay,
    int? dueDay,
    Money? currentOutstanding,
    DateTime? outstandingUpdatedAt,
    bool clearOutstanding = false,
    int? styleIndex,
  }) {
    return CreditCard(
      id: id,
      name: name ?? this.name,
      issuer: issuer ?? this.issuer,
      last4: clearLast4 ? null : (last4 ?? this.last4),
      creditLimit: creditLimit ?? this.creditLimit,
      statementDay: statementDay ?? this.statementDay,
      dueDay: dueDay ?? this.dueDay,
      currentOutstanding: clearOutstanding
          ? null
          : (currentOutstanding ?? this.currentOutstanding),
      outstandingUpdatedAt: clearOutstanding
          ? null
          : (outstandingUpdatedAt ?? this.outstandingUpdatedAt),
      styleIndex: styleIndex ?? this.styleIndex,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CreditCard &&
      other.id == id &&
      other.name == name &&
      other.issuer == issuer &&
      other.last4 == last4 &&
      other.creditLimit == creditLimit &&
      other.statementDay == statementDay &&
      other.dueDay == dueDay &&
      other.currentOutstanding == currentOutstanding &&
      other.outstandingUpdatedAt == outstandingUpdatedAt &&
      other.styleIndex == styleIndex;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    issuer,
    last4,
    creditLimit,
    statementDay,
    dueDay,
    currentOutstanding,
    outstandingUpdatedAt,
    styleIndex,
  );
}
