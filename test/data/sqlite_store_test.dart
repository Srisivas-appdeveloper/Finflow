import 'dart:io';

import 'package:finflow/data/sources/sqlite_finance_store.dart';
import 'package:finflow/domain/entities/money.dart';
import 'package:finflow/domain/entities/split.dart';
import 'package:finflow/domain/entities/transaction.dart';
import 'package:finflow/domain/entities/transaction_category.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import '../fixtures/sample_data.dart';

/// Exercises the real SQLite store (via the desktop FFI driver).
void main() {
  sqfliteFfiInit();
  final now = DateTime(2026, 10, 24, 18, 30);

  late SqliteFinanceStore store;
  setUp(() async {
    store = await SqliteFinanceStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
  });
  tearDown(() => store.close());

  test('round-trips every record type exactly', () async {
    final bundle = const SampleDataGenerator().generate(now);
    await store.putAll(
      transactions: bundle.transactions,
      cards: bundle.cards,
      bills: bundle.bills,
      emis: bundle.emis,
    );

    final txns = await store.transactions();
    expect(txns, hasLength(bundle.transactions.length));
    final byId = {for (final t in txns) t.id: t};
    for (final original in bundle.transactions) {
      final stored = byId[original.id]!;
      expect(stored, original);
      expect(stored.reference, original.reference);
      expect(stored.billId, original.billId);
    }
    // Newest first.
    expect(
      txns.first.occurredAt.isAfter(txns.last.occurredAt) ||
          txns.first.occurredAt == txns.last.occurredAt,
      isTrue,
    );

    expect(await store.cards(), unorderedEquals(bundle.cards));
    final bills = await store.bills();
    expect(
      bills.map((b) => b.id),
      unorderedEquals(bundle.bills.map((b) => b.id)),
    );
    for (final b in bills) {
      final original = bundle.bills.firstWhere((x) => x.id == b.id);
      expect(b.totalDue, original.totalDue);
      expect(b.minimumDue, original.minimumDue);
      expect(b.dueDate, original.dueDate);
    }
    expect(await store.emis(), unorderedEquals(bundle.emis));
  });

  test('replace, delete and cascading card deletion', () async {
    final bundle = const SampleDataGenerator().generate(now);
    await store.putAll(
      cards: bundle.cards,
      bills: bundle.bills,
      emis: bundle.emis,
    );

    final t = bundle.transactions.first;
    await store.putTransaction(t);
    await store.putTransaction(t.copyWith(title: 'Renamed'));
    expect((await store.transactions()).single.title, 'Renamed');
    await store.deleteTransaction(t.id);
    expect(await store.transactions(), isEmpty);

    final card = bundle.cards.first;
    await store.deleteCard(card.id);
    expect((await store.bills()).where((b) => b.cardId == card.id), isEmpty);
    expect((await store.emis()).where((e) => e.cardId == card.id), isEmpty);
  });

  test(
    'editing a card keeps its bills and EMIs (no cascade on update)',
    () async {
      final bundle = const SampleDataGenerator().generate(now);
      await store.putAll(
        cards: bundle.cards,
        bills: bundle.bills,
        emis: bundle.emis,
      );
      final card = bundle.cards.first;
      final billsBefore = (await store.bills())
          .where((b) => b.cardId == card.id)
          .length;
      final emisBefore = (await store.emis())
          .where((e) => e.cardId == card.id)
          .length;
      expect(billsBefore, greaterThan(0));
      expect(emisBefore, greaterThan(0));

      await store.putCard(card.copyWith(name: 'Renamed', styleIndex: 3));
      await store.putAll(cards: [card.copyWith(name: 'Renamed again')]);

      expect(
        (await store.cards()).firstWhere((c) => c.id == card.id).name,
        'Renamed again',
      );
      expect(
        (await store.bills()).where((b) => b.cardId == card.id),
        hasLength(billsBefore),
      );
      expect(
        (await store.emis()).where((e) => e.cardId == card.id),
        hasLength(emisBefore),
      );
    },
  );

  test('clearAll empties every table', () async {
    final bundle = const SampleDataGenerator().generate(now);
    await store.putAll(
      transactions: bundle.transactions,
      cards: bundle.cards,
      bills: bundle.bills,
      emis: bundle.emis,
    );
    await store.clearAll();
    expect(await store.transactions(), isEmpty);
    expect(await store.cards(), isEmpty);
    expect(await store.bills(), isEmpty);
    expect(await store.emis(), isEmpty);
  });

  test('split groups, expenses and settlements round-trip', () async {
    final group = SplitGroup(
      id: 'g1',
      name: 'Room 204',
      members: const [
        SplitMember(id: 'm1', name: 'Arun'),
        SplitMember(id: 'm2', name: 'Bala'),
      ],
      createdAt: now,
    );
    final expense = SplitExpense(
      id: 'e1',
      groupId: 'g1',
      title: 'Rent',
      amount: const Money(900000),
      category: TransactionCategory.bills,
      paidBy: 'm1',
      mode: SplitMode.shares,
      shares: const [
        SplitShare(
          memberId: SplitMember.youId,
          amount: Money(450000),
          units: 2,
        ),
        SplitShare(memberId: 'm1', amount: Money(225000)),
        SplitShare(memberId: 'm2', amount: Money(225000)),
      ],
      occurredAt: now,
    );
    final settlement = SplitSettlement(
      id: 's1',
      groupId: 'g1',
      fromId: SplitMember.youId,
      toId: 'm1',
      amount: const Money(450000),
      occurredAt: now,
    );
    final mirror = Transaction(
      id: 't1',
      title: 'Rent',
      amount: const Money(900000),
      share: const Money(450000),
      splitId: 'e1',
      direction: TransactionDirection.debit,
      category: TransactionCategory.bills,
      status: TransactionStatus.completed,
      occurredAt: now,
      paymentMethod: PaymentMethod.paidByOther,
    );
    await store.putAll(
      splitGroups: [group],
      splitExpenses: [expense],
      splitSettlements: [settlement],
      transactions: [mirror],
    );

    final g = (await store.splitGroups()).single;
    expect(g.name, 'Room 204');
    expect(g.members, group.members);
    final e = (await store.splitExpenses()).single;
    expect(e.shares, expense.shares);
    expect(e.mode, SplitMode.shares);
    expect(e.paidBy, 'm1');
    final st = (await store.splitSettlements()).single;
    expect(st.fromId, SplitMember.youId);
    expect(st.amount, settlement.amount);
    expect((await store.transactions()).single, mirror);

    // Renaming the group and its people keeps expenses and shares.
    await store.putSplitGroup(
      group.copyWith(
        name: 'Room 205',
        members: const [SplitMember(id: 'm1', name: 'Arun K')],
      ),
    );
    expect((await store.splitExpenses()).single.shares, hasLength(3));
    expect((await store.splitSettlements()), hasLength(1));

    // Editing an expense replaces its shares.
    await store.putSplitExpense(
      SplitExpense(
        id: 'e1',
        groupId: 'g1',
        title: 'Rent',
        amount: const Money(100),
        category: TransactionCategory.bills,
        paidBy: SplitMember.youId,
        mode: SplitMode.equal,
        shares: const [SplitShare(memberId: 'm1', amount: Money(100))],
        occurredAt: now,
      ),
    );
    expect((await store.splitExpenses()).single.shares, hasLength(1));

    await store.clearAll();
    expect(await store.splitGroups(), isEmpty);
    expect(await store.splitExpenses(), isEmpty);
    expect(await store.splitSettlements(), isEmpty);
  });

  test('upgrading from schema 1 keeps existing transactions', () async {
    final dir = await Directory.systemTemp.createTemp('finflow');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/v1.db';

    // A version 1 database as shipped before splits.
    final v1 = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE transactions (
              id TEXT PRIMARY KEY, title TEXT NOT NULL,
              amount_minor INTEGER NOT NULL, currency TEXT NOT NULL,
              direction TEXT NOT NULL, category TEXT NOT NULL,
              status TEXT NOT NULL, occurred_at INTEGER NOT NULL,
              payment_method TEXT NOT NULL, reference TEXT, note TEXT,
              bill_id TEXT)''');
          await db.execute(
            'CREATE INDEX idx_transactions_occurred '
            'ON transactions(occurred_at)',
          );
          await db.execute(
            'CREATE INDEX idx_transactions_bill ON transactions(bill_id)',
          );
        },
      ),
    );
    await v1.insert('transactions', {
      'id': 'old',
      'title': 'Chai',
      'amount_minor': 2000,
      'currency': 'INR',
      'direction': 'debit',
      'category': 'dining',
      'status': 'completed',
      'occurred_at': now.millisecondsSinceEpoch,
      'payment_method': 'cash',
    });
    await v1.close();

    final upgraded = await SqliteFinanceStore.open(
      factory: databaseFactoryFfiNoIsolate,
      path: path,
    );
    addTearDown(upgraded.close);
    final t = (await upgraded.transactions()).single;
    expect(t.title, 'Chai');
    expect(t.share, isNull);
    expect(t.splitId, isNull);
    expect(await upgraded.splitGroups(), isEmpty);
  });
}
