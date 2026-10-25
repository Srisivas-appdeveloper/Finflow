import '../entities/money.dart';
import '../entities/split.dart';

/// Divides amounts between people. Results are in whole minor units and
/// always add up exactly to the total: leftover paise go to the first
/// people in the list.
abstract final class SplitCalculator {
  /// [total] divided evenly between [ids].
  static Map<String, Money> equal(Money total, List<String> ids) =>
      byShares(total, {for (final id in ids) id: 1});

  /// [total] divided in proportion to each person's units (largest
  /// remainder method). People with zero units get nothing.
  static Map<String, Money> byShares(Money total, Map<String, int> units) {
    final active = [
      for (final e in units.entries)
        if (e.value > 0) e,
    ];
    final sum = active.fold(0, (s, e) => s + e.value);
    if (sum == 0) return const {};
    final base = <String, int>{};
    final remainders = <(String, int, int)>[];
    var assigned = 0;
    for (var i = 0; i < active.length; i++) {
      final e = active[i];
      final exact = total.minor * e.value;
      base[e.key] = exact ~/ sum;
      assigned += base[e.key]!;
      remainders.add((e.key, exact % sum, i));
    }
    // Hand out the leftover minor units, largest remainder first; ties go
    // to whoever comes first.
    remainders.sort((a, b) {
      final byRemainder = b.$2.compareTo(a.$2);
      return byRemainder != 0 ? byRemainder : a.$3.compareTo(b.$3);
    });
    var left = total.minor - assigned;
    for (final r in remainders) {
      if (left == 0) break;
      base[r.$1] = base[r.$1]! + 1;
      left--;
    }
    return {
      for (final e in active)
        e.key: Money(base[e.key]!, currencyCode: total.currencyCode),
    };
  }
}

/// Who owes whom in one group, from its expenses and settlements.
///
/// A positive balance means the person should get money back; negative
/// means they owe the group.
class SplitLedger {
  SplitLedger({
    required this.group,
    required List<SplitExpense> expenses,
    required List<SplitSettlement> settlements,
    required this.currencyCode,
  }) : expenses = [
         for (final e in expenses)
           if (e.groupId == group.id) e,
       ],
       settlements = [
         for (final s in settlements)
           if (s.groupId == group.id) s,
       ];

  final SplitGroup group;
  final List<SplitExpense> expenses;
  final List<SplitSettlement> settlements;
  final String currencyCode;

  Money get _zero => Money.zero(currencyCode: currencyCode);

  late final Map<String, Money> balances = _balances();

  Map<String, Money> _balances() {
    final minor = <String, int>{for (final id in group.everyoneIds) id: 0};
    void add(String id, int amount) => minor[id] = (minor[id] ?? 0) + amount;
    for (final e in expenses) {
      add(e.paidBy, e.amount.minor);
      for (final s in e.shares) {
        add(s.memberId, -s.amount.minor);
      }
    }
    for (final s in settlements) {
      // Paying someone back reduces what you owe (raises your balance).
      add(s.fromId, s.amount.minor);
      add(s.toId, -s.amount.minor);
    }
    return {
      for (final e in minor.entries)
        e.key: Money(e.value, currencyCode: currencyCode),
    };
  }

  Money balanceOf(String id) => balances[id] ?? _zero;

  /// The user's balance: positive when others owe the user.
  Money get yourBalance => balanceOf(SplitMember.youId);

  Money get totalSpent => expenses.fold(_zero, (sum, e) => sum + e.amount);

  bool get isSettled => balances.values.every((b) => b.isZero);

  /// The fewest straightforward payments that settle every balance: the
  /// person who owes most pays the person owed most, and so on.
  late final List<SplitTransfer> settleUp = _settleUp();

  List<SplitTransfer> _settleUp() {
    final order = group.everyoneIds;
    int rank(String id) {
      final i = order.indexOf(id);
      return i < 0 ? order.length : i;
    }

    final owed = [
      for (final e in balances.entries)
        if (e.value.isPositive) _Open(e.key, e.value.minor),
    ];
    final owing = [
      for (final e in balances.entries)
        if (e.value.isNegative) _Open(e.key, -e.value.minor),
    ];
    int largestFirst(_Open a, _Open b) {
      final c = b.minor.compareTo(a.minor);
      return c != 0 ? c : rank(a.id).compareTo(rank(b.id));
    }

    final transfers = <SplitTransfer>[];
    while (owed.isNotEmpty && owing.isNotEmpty) {
      owed.sort(largestFirst);
      owing.sort(largestFirst);
      final creditor = owed.first;
      final debtor = owing.first;
      final amount = creditor.minor < debtor.minor
          ? creditor.minor
          : debtor.minor;
      transfers.add(
        SplitTransfer(
          debtor.id,
          creditor.id,
          Money(amount, currencyCode: currencyCode),
        ),
      );
      creditor.minor -= amount;
      debtor.minor -= amount;
      if (creditor.minor == 0) owed.removeAt(0);
      if (debtor.minor == 0) owing.removeAt(0);
    }
    return transfers;
  }

  /// Plain-text summary for sharing with the group.
  String summary(String Function(Money) money) {
    final b = StringBuffer()
      ..writeln(group.name)
      ..writeln('Total spent: ${money(totalSpent)}');
    if (isSettled) {
      b
        ..writeln()
        ..writeln('Everyone is settled up.');
    } else {
      b
        ..writeln()
        ..writeln('Balances');
      for (final id in group.everyoneIds) {
        final v = balanceOf(id);
        if (v.isZero) continue;
        final name = group.nameOf(id);
        final you = id == SplitMember.youId;
        b.writeln(
          v.isPositive
              ? '$name ${you ? 'get' : 'gets'} back ${money(v)}'
              : '$name ${you ? 'owe' : 'owes'} ${money(v.abs())}',
        );
      }
      b
        ..writeln()
        ..writeln('To settle up');
      for (final t in settleUp) {
        final you = t.fromId == SplitMember.youId;
        b.writeln(
          '${group.nameOf(t.fromId)} ${you ? 'pay' : 'pays'} '
          '${group.nameOf(t.toId)} ${money(t.amount)}',
        );
      }
    }
    b
      ..writeln()
      ..write('Shared from FinFlow');
    return b.toString();
  }
}

/// An unsettled balance while working out [SplitLedger.settleUp].
class _Open {
  _Open(this.id, this.minor);
  final String id;
  int minor;
}
