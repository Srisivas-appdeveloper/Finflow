import 'package:finflow/data/repositories/data_management_repository_impl.dart';
import 'package:finflow/data/repositories/split_repository_impl.dart';
import 'package:finflow/data/repositories/transaction_repository_impl.dart';
import 'package:finflow/data/sources/finance_store.dart';
import 'package:finflow/domain/entities/money.dart';
import 'package:finflow/domain/entities/split.dart';
import 'package:finflow/domain/entities/transaction.dart';
import 'package:finflow/domain/entities/transaction_category.dart';
import 'package:finflow/domain/repositories/split_repository.dart';
import 'package:finflow/domain/services/transaction_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

const you = SplitMember.youId;
final when = DateTime(2026, 10, 10, 12);
final now = DateTime(2026, 10, 24, 18);

void main() {
  late InMemoryFinanceStore store;
  late DataChanges changes;
  late SplitRepositoryImpl splits;
  late TransactionRepositoryImpl transactions;
  const analytics = TransactionAnalytics();

  setUp(() {
    store = InMemoryFinanceStore();
    changes = DataChanges();
    splits = SplitRepositoryImpl(store, changes);
    transactions = TransactionRepositoryImpl(store, changes);
  });

  Future<SplitGroup> room() => splits.saveGroup(
    SplitGroup(
      id: '',
      name: ' Room 204 ',
      members: const [
        SplitMember(id: '', name: 'Arun'),
        SplitMember(id: '', name: 'Bala'),
      ],
      createdAt: when,
    ),
  );

  SplitExpense expense(
    SplitGroup g, {
    required String paidBy,
    required Map<String, int> shares,
    String id = '',
  }) => SplitExpense(
    id: id,
    groupId: g.id,
    title: 'Groceries',
    amount: Money(shares.values.fold(0, (a, b) => a + b)),
    category: TransactionCategory.groceries,
    paidBy: paidBy,
    mode: SplitMode.amounts,
    shares: [
      for (final e in shares.entries)
        SplitShare(memberId: e.key, amount: Money(e.value)),
    ],
    occurredAt: when,
  );

  test('groups: trims, assigns ids, validates names', () async {
    final g = await room();
    expect(g.id, isNotEmpty);
    expect(g.name, 'Room 204');
    expect(g.members.map((m) => m.id), everyElement(isNotEmpty));
    expect(await splits.groups(), hasLength(1));

    Future<void> bad(List<String> names) => splits.saveGroup(
      SplitGroup(
        id: '',
        name: 'X',
        members: [for (final n in names) SplitMember(id: '', name: n)],
        createdAt: when,
      ),
    );
    expect(() => bad([]), throwsArgumentError);
    expect(() => bad(['You']), throwsArgumentError);
    expect(() => bad(['Arun', 'arun']), throwsArgumentError);
  });

  test('paid by you: full amount leaves, only your share counts', () async {
    final g = await room();
    final a = g.members[0].id, b = g.members[1].id;
    final e = await splits.saveExpense(
      expense(g, paidBy: you, shares: {you: 100000, a: 100000, b: 100000}),
      method: PaymentMethod.cash,
    );

    final t = (await transactions.getAll()).single;
    expect(t.amount.minor, 300000);
    expect(t.share!.minor, 100000);
    expect(t.splitId, e.id);
    expect(t.paymentMethod, PaymentMethod.cash);
    expect(t.category, TransactionCategory.groceries);

    final month = analytics.monthSummary([t], now);
    expect(month.spending.minor, 100000);
    final cats = analytics.spendingByCategory([t], from: DateTime(2026, 10));
    expect(cats.single.amount.minor, 100000);
  });

  test('paid by someone else: your share is your spending', () async {
    final g = await room();
    final a = g.members[0].id, b = g.members[1].id;
    await splits.saveExpense(
      expense(g, paidBy: a, shares: {you: 50000, a: 50000, b: 50000}),
    );
    final t = (await transactions.getAll()).single;
    expect(t.amount.minor, 50000);
    expect(t.share, isNull);
    expect(t.paymentMethod, PaymentMethod.paidByOther);
    expect(analytics.monthSummary([t], now).spending.minor, 50000);

    // Not part of it and didn't pay: nothing in your activity.
    await splits.saveExpense(expense(g, paidBy: a, shares: {a: 1000, b: 1000}));
    expect(await transactions.getAll(), hasLength(1));
  });

  test('editing the payer rewrites the same transaction', () async {
    final g = await room();
    final a = g.members[0].id;
    final e = await splits.saveExpense(
      expense(g, paidBy: you, shares: {you: 4000, a: 6000}),
      method: PaymentMethod.card,
    );
    final first = (await transactions.getAll()).single;

    await splits.saveExpense(
      expense(g, id: e.id, paidBy: a, shares: {you: 4000, a: 6000}),
    );
    var t = (await transactions.getAll()).single;
    expect(t.id, first.id);
    expect(t.amount.minor, 4000);
    expect(t.paymentMethod, PaymentMethod.paidByOther);

    // Back to you, keeping the method when none is given.
    await splits.saveExpense(
      expense(g, id: e.id, paidBy: you, shares: {you: 4000, a: 6000}),
      method: PaymentMethod.card,
    );
    t = (await transactions.getAll()).single;
    expect(t.amount.minor, 10000);
    expect(t.share!.minor, 4000);
    expect(t.paymentMethod, PaymentMethod.card);

    // Taken out of the split while someone else paid: transaction removed.
    await splits.saveExpense(
      expense(g, id: e.id, paidBy: a, shares: {a: 10000}),
    );
    expect(await transactions.getAll(), isEmpty);
  });

  test('shares must add up and belong to the group', () async {
    final g = await room();
    final a = g.members[0].id;
    final wrongTotal = SplitExpense(
      id: '',
      groupId: g.id,
      title: 'Rent',
      amount: const Money(10000),
      category: TransactionCategory.bills,
      paidBy: you,
      mode: SplitMode.amounts,
      shares: [SplitShare(memberId: a, amount: const Money(9000))],
      occurredAt: when,
    );
    expect(() => splits.saveExpense(wrongTotal), throwsArgumentError);
    expect(
      () => splits.saveExpense(
        expense(g, paidBy: you, shares: {'stranger': 100}),
      ),
      throwsArgumentError,
    );
    expect(
      () => splits.saveExpense(expense(g, paidBy: 'nobody', shares: {a: 1})),
      throwsArgumentError,
    );
  });

  test('splitting an existing spend links it instead of duplicating', () async {
    final g = await room();
    final a = g.members[0].id;
    final original = await transactions.add(
      Transaction(
        id: '',
        title: 'Big Basket',
        amount: const Money(90000),
        direction: TransactionDirection.debit,
        category: TransactionCategory.groceries,
        status: TransactionStatus.completed,
        occurredAt: when,
        paymentMethod: PaymentMethod.card,
        note: 'Weekly shop',
      ),
    );
    await splits.saveExpense(
      expense(g, paidBy: you, shares: {you: 45000, a: 45000}),
      transactionId: original.id,
    );
    final t = (await transactions.getAll()).single;
    expect(t.id, original.id);
    expect(t.share!.minor, 45000);
    expect(t.paymentMethod, PaymentMethod.card);
    expect(t.note, 'Weekly shop');

    // A split spend can't be split again.
    expect(
      () => splits.saveExpense(
        expense(g, paidBy: you, shares: {you: 1, a: 1}),
        transactionId: original.id,
      ),
      throwsArgumentError,
    );
  });

  test('deleting either side removes both', () async {
    final g = await room();
    final a = g.members[0].id;
    final e = await splits.saveExpense(
      expense(g, paidBy: you, shares: {you: 500, a: 500}),
    );
    await splits.deleteExpense(e.id);
    expect(await transactions.getAll(), isEmpty);

    final e2 = await splits.saveExpense(
      expense(g, paidBy: you, shares: {you: 500, a: 500}),
    );
    final t = (await transactions.getAll()).single;
    await transactions.delete(t.id);
    expect(await splits.expenses(), isEmpty);
    expect(() => splits.expense(e2.id), throwsA(isA<SplitNotFoundException>()));
  });

  test('settlements are movements and only mirror your own payments', () async {
    final g = await room();
    final a = g.members[0].id, b = g.members[1].id;
    await splits.saveExpense(
      expense(g, paidBy: you, shares: {you: 1000, a: 1000, b: 1000}),
    );
    final received = await splits.saveSettlement(
      SplitSettlement(
        id: '',
        groupId: g.id,
        fromId: a,
        toId: you,
        amount: const Money(1000),
        occurredAt: when,
      ),
      method: PaymentMethod.upi,
    );
    await splits.saveSettlement(
      SplitSettlement(
        id: '',
        groupId: g.id,
        fromId: b,
        toId: a,
        amount: const Money(300),
        occurredAt: when,
      ),
    );
    final all = await transactions.getAll();
    expect(all, hasLength(2));
    final settlement = all.firstWhere((t) => t.splitId == received.id);
    expect(settlement.isCredit, isTrue);
    expect(settlement.category, TransactionCategory.settlement);
    expect(settlement.title, 'Arun');

    final month = analytics.monthSummary(all, now);
    expect(month.income.isZero, isTrue);
    expect(month.spending.minor, 1000);

    expect(
      () => splits.saveSettlement(
        SplitSettlement(
          id: '',
          groupId: g.id,
          fromId: a,
          toId: a,
          amount: const Money(1),
          occurredAt: when,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('members with records cannot be removed', () async {
    final g = await room();
    final a = g.members[0];
    await splits.saveExpense(
      expense(g, paidBy: a.id, shares: {a.id: 100, you: 100}),
    );
    expect(
      () => splits.saveGroup(g.copyWith(members: [g.members[1]])),
      throwsA(isA<MemberInUseException>()),
    );
    // Bala has no records and can go; renames keep ids.
    final saved = await splits.saveGroup(
      g.copyWith(
        members: [SplitMember(id: a.id, name: 'Arun K')],
      ),
    );
    expect(saved.members.single.id, a.id);
    expect((await splits.expenses()).single.paidBy, a.id);
  });

  test('deleting a group keeps your transactions, unlinked', () async {
    final g = await room();
    final a = g.members[0].id;
    await splits.saveExpense(
      expense(g, paidBy: you, shares: {you: 700, a: 300}),
    );
    await splits.deleteGroup(g.id);
    expect(await splits.groups(), isEmpty);
    expect(await splits.expenses(), isEmpty);
    final t = (await transactions.getAll()).single;
    expect(t.splitId, isNull);
    expect(t.share!.minor, 700);
  });

  test('clear all removes groups; CSV has your share', () async {
    final g = await room();
    final a = g.members[0].id;
    await splits.saveExpense(
      expense(g, paidBy: you, shares: {you: 700, a: 300}),
    );
    final data = DataManagementRepositoryImpl(store, changes);
    final csv = await data.exportTransactionsCsv();
    expect(csv.split('\n').first, contains('your_share'));
    expect(csv, contains('10.00,7.00,INR'));

    await data.clearAll();
    expect(await splits.groups(), isEmpty);
    expect(await splits.expenses(), isEmpty);
  });
}
