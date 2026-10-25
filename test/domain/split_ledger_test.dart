import 'package:finflow/domain/entities/money.dart';
import 'package:finflow/domain/entities/split.dart';
import 'package:finflow/domain/entities/transaction_category.dart';
import 'package:finflow/domain/services/split_ledger.dart';
import 'package:flutter_test/flutter_test.dart';

const you = SplitMember.youId;

final room = SplitGroup(
  id: 'g1',
  name: 'Room 204',
  members: const [
    SplitMember(id: 'a', name: 'Arun'),
    SplitMember(id: 'b', name: 'Bala'),
  ],
  createdAt: DateTime(2026, 10, 1),
);

SplitExpense expense(
  String paidBy,
  Map<String, int> shares, {
  String id = 'e',
}) {
  final total = shares.values.fold(0, (a, b) => a + b);
  return SplitExpense(
    id: id,
    groupId: 'g1',
    title: 'Rent',
    amount: Money(total),
    category: TransactionCategory.bills,
    paidBy: paidBy,
    mode: SplitMode.amounts,
    shares: [
      for (final e in shares.entries)
        SplitShare(memberId: e.key, amount: Money(e.value)),
    ],
    occurredAt: DateTime(2026, 10, 2),
  );
}

SplitLedger ledger(
  List<SplitExpense> expenses, [
  List<SplitSettlement> settlements = const [],
]) => SplitLedger(
  group: room,
  expenses: expenses,
  settlements: settlements,
  currencyCode: 'INR',
);

Map<String, int> minor(Map<String, Money> m) => {
  for (final e in m.entries) e.key: e.value.minor,
};

void main() {
  group('SplitCalculator', () {
    test('equal split adds up exactly, extra paise to the first people', () {
      final r = SplitCalculator.equal(const Money(1000), [you, 'a', 'b']);
      expect(minor(r), {you: 334, 'a': 333, 'b': 333});
    });

    test('shares split in proportion, largest remainder first', () {
      final r = SplitCalculator.byShares(const Money(1001), {
        you: 2,
        'a': 1,
        'b': 1,
      });
      expect(minor(r), {you: 501, 'a': 250, 'b': 250});
      expect(r.values.fold(0, (s, m) => s + m.minor), 1001);
    });

    test('zero units get nothing; no units at all gives an empty split', () {
      final r = SplitCalculator.byShares(const Money(900), {
        you: 1,
        'a': 0,
        'b': 2,
      });
      expect(minor(r), {you: 300, 'b': 600});
      expect(SplitCalculator.byShares(const Money(900), {you: 0}), isEmpty);
    });
  });

  group('SplitLedger', () {
    test('balances: payer gets back what others owe', () {
      // You paid 3000 for all three equally.
      final l = ledger([
        expense(you, {you: 1000, 'a': 1000, 'b': 1000}),
      ]);
      expect(l.yourBalance.minor, 2000);
      expect(l.balanceOf('a').minor, -1000);
      expect(l.balanceOf('b').minor, -1000);
      expect(l.totalSpent.minor, 3000);
      expect(l.isSettled, isFalse);
    });

    test('settlements move balances back to zero', () {
      final l = ledger(
        [
          expense(you, {you: 1000, 'a': 1000, 'b': 1000}),
        ],
        [
          SplitSettlement(
            id: 's',
            groupId: 'g1',
            fromId: 'a',
            toId: you,
            amount: const Money(1000),
            occurredAt: DateTime(2026, 10, 3),
          ),
        ],
      );
      expect(l.yourBalance.minor, 1000);
      expect(l.balanceOf('a').isZero, isTrue);
      expect(l.settleUp, [const SplitTransfer('b', you, Money(1000))]);
    });

    test('settle up uses few payments and clears every balance', () {
      final l = ledger([
        // Arun paid rent 9000 for all; you paid groceries 3000 for all.
        expense('a', {you: 3000, 'a': 3000, 'b': 3000}, id: 'e1'),
        expense(you, {you: 1000, 'a': 1000, 'b': 1000}, id: 'e2'),
      ]);
      // You: -3000 + 2000 = -1000; Arun: +6000 - 1000 = 5000; Bala: -4000.
      expect(l.yourBalance.minor, -1000);
      expect(l.balanceOf('a').minor, 5000);
      expect(l.balanceOf('b').minor, -4000);
      expect(l.settleUp, [
        const SplitTransfer('b', 'a', Money(4000)),
        const SplitTransfer(you, 'a', Money(1000)),
      ]);
      // Applying the suggestions settles everyone.
      final settled = ledger(l.expenses, [
        for (final (i, t) in l.settleUp.indexed)
          SplitSettlement(
            id: 's$i',
            groupId: 'g1',
            fromId: t.fromId,
            toId: t.toId,
            amount: t.amount,
            occurredAt: DateTime(2026, 10, 9),
          ),
      ]);
      expect(settled.isSettled, isTrue);
      expect(settled.settleUp, isEmpty);
    });

    test('ignores records from other groups', () {
      final other = SplitExpense(
        id: 'x',
        groupId: 'other',
        title: 'Trip',
        amount: const Money(500),
        category: TransactionCategory.travel,
        paidBy: you,
        mode: SplitMode.equal,
        shares: const [SplitShare(memberId: 'a', amount: Money(500))],
        occurredAt: DateTime(2026, 10, 2),
      );
      expect(ledger([other]).isSettled, isTrue);
    });

    test('summary reads naturally for sharing', () {
      final l = ledger([
        expense(you, {you: 1000, 'a': 1000, 'b': 1000}),
      ]);
      final text = l.summary((m) => '₹${m.minor ~/ 100}');
      expect(text, contains('Room 204'));
      expect(text, contains('Total spent: ₹30'));
      expect(text, contains('You get back ₹20'));
      expect(text, contains('Arun owes ₹10'));
      expect(text, contains('Arun pays You ₹10'));
    });
  });
}
