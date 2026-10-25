import 'package:meta/meta.dart';

import 'money.dart';
import 'transaction_category.dart';

/// A person in a split group other than the user.
@immutable
class SplitMember {
  const SplitMember({required this.id, required this.name});

  /// Stands for the user wherever a member id is expected (payer, shares,
  /// settlements). The user is never stored as a member.
  static const youId = 'you';

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is SplitMember && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// People who share costs, such as a hostel room or a trip.
@immutable
class SplitGroup {
  const SplitGroup({
    required this.id,
    required this.name,
    required this.members,
    required this.createdAt,
  });

  final String id;
  final String name;

  /// Everyone except the user, in the order they were added.
  final List<SplitMember> members;
  final DateTime createdAt;

  /// The user first, then the members.
  List<String> get everyoneIds => [
    SplitMember.youId,
    for (final m in members) m.id,
  ];

  bool has(String id) =>
      id == SplitMember.youId || members.any((m) => m.id == id);

  /// "You" for the user, the member's name, or "Former member" if they were
  /// removed.
  String nameOf(String id) {
    if (id == SplitMember.youId) return 'You';
    for (final m in members) {
      if (m.id == id) return m.name;
    }
    return 'Former member';
  }

  SplitGroup copyWith({String? name, List<SplitMember>? members}) => SplitGroup(
    id: id,
    name: name ?? this.name,
    members: members ?? this.members,
    createdAt: createdAt,
  );
}

/// How an expense is divided.
enum SplitMode {
  equal('Equally'),
  amounts('By amount'),
  shares('By shares');

  const SplitMode(this.label);
  final String label;
}

/// One person's part of an expense.
@immutable
class SplitShare {
  const SplitShare({
    required this.memberId,
    required this.amount,
    this.units = 1,
  });

  final String memberId;
  final Money amount;

  /// Weight used in [SplitMode.shares] (e.g. 2 for someone staying twice as
  /// long). Kept so the split can be edited the way it was entered.
  final int units;

  @override
  bool operator ==(Object other) =>
      other is SplitShare &&
      other.memberId == memberId &&
      other.amount == amount &&
      other.units == units;

  @override
  int get hashCode => Object.hash(memberId, amount, units);
}

/// A cost paid by one person and shared by some or all of the group.
@immutable
class SplitExpense {
  const SplitExpense({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amount,
    required this.category,
    required this.paidBy,
    required this.mode,
    required this.shares,
    required this.occurredAt,
  });

  final String id;
  final String groupId;
  final String title;

  /// The full amount paid.
  final Money amount;
  final TransactionCategory category;

  /// Member id of whoever paid, or [SplitMember.youId].
  final String paidBy;
  final SplitMode mode;

  /// Who shares the cost; amounts add up to [amount].
  final List<SplitShare> shares;
  final DateTime occurredAt;

  Money shareOf(String memberId) {
    for (final s in shares) {
      if (s.memberId == memberId) return s.amount;
    }
    return Money.zero(currencyCode: amount.currencyCode);
  }

  Money get yourShare => shareOf(SplitMember.youId);

  bool get paidByYou => paidBy == SplitMember.youId;

  bool involves(String memberId) =>
      paidBy == memberId || shares.any((s) => s.memberId == memberId);
}

/// Money paid from one person to another to settle up.
@immutable
class SplitSettlement {
  const SplitSettlement({
    required this.id,
    required this.groupId,
    required this.fromId,
    required this.toId,
    required this.amount,
    required this.occurredAt,
  });

  final String id;
  final String groupId;

  /// Who paid.
  final String fromId;

  /// Who received.
  final String toId;
  final Money amount;
  final DateTime occurredAt;

  bool involves(String memberId) => fromId == memberId || toId == memberId;
}

/// A payment that would settle a balance: [fromId] pays [toId].
@immutable
class SplitTransfer {
  const SplitTransfer(this.fromId, this.toId, this.amount);

  final String fromId;
  final String toId;
  final Money amount;

  @override
  bool operator ==(Object other) =>
      other is SplitTransfer &&
      other.fromId == fromId &&
      other.toId == toId &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(fromId, toId, amount);

  @override
  String toString() => 'SplitTransfer($fromId → $toId, ${amount.minor})';
}
