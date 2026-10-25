import 'dart:async';
import 'dart:math';

import '../../domain/entities/card_bill.dart';
import '../../domain/entities/credit_card.dart';
import '../../domain/entities/emi_plan.dart';
import '../../domain/entities/split.dart';
import '../../domain/entities/transaction.dart';

/// Raw persistence for financial records. Repositories add the business
/// rules (derived bill payments, change notifications) on top.
///
/// Bills are stored without their paid amount, which is always derived from
/// linked payment transactions.
abstract interface class FinanceStore {
  Future<List<Transaction>> transactions();
  Future<void> putTransaction(Transaction transaction);
  Future<void> deleteTransaction(String id);

  Future<List<CreditCard>> cards();
  Future<void> putCard(CreditCard card);
  Future<void> deleteCard(String id);

  Future<List<CardBill>> bills();
  Future<void> putBill(CardBill bill);
  Future<void> deleteBill(String id);

  Future<List<EmiPlan>> emis();
  Future<void> putEmi(EmiPlan plan);
  Future<void> deleteEmi(String id);

  /// Groups with their members.
  Future<List<SplitGroup>> splitGroups();
  Future<void> putSplitGroup(SplitGroup group);

  /// Deletes only the group row; repositories delete its records first.
  Future<void> deleteSplitGroup(String id);

  Future<List<SplitExpense>> splitExpenses();
  Future<void> putSplitExpense(SplitExpense expense);
  Future<void> deleteSplitExpense(String id);

  Future<List<SplitSettlement>> splitSettlements();
  Future<void> putSplitSettlement(SplitSettlement settlement);
  Future<void> deleteSplitSettlement(String id);

  /// Inserts or replaces many records in one atomic step.
  Future<void> putAll({
    List<Transaction> transactions = const [],
    List<CreditCard> cards = const [],
    List<CardBill> bills = const [],
    List<EmiPlan> emis = const [],
    List<SplitGroup> splitGroups = const [],
    List<SplitExpense> splitExpenses = const [],
    List<SplitSettlement> splitSettlements = const [],
  });

  Future<void> clearAll();
}

/// App-wide "data changed" signal shared by all repositories, so that e.g.
/// deleting a payment transaction also refreshes the bill it settled.
class DataChanges {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  void notify() => _controller.add(null);

  void dispose() => _controller.close();
}

/// Unique, roughly time-ordered identifiers for new records.
abstract final class Ids {
  static final _rng = Random.secure();

  static String next(String prefix) {
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final rand = List.generate(
      6,
      (_) => _rng.nextInt(36).toRadixString(36),
    ).join();
    return '$prefix-$time$rand';
  }
}

/// Non-persistent [FinanceStore] for tests and previews.
class InMemoryFinanceStore implements FinanceStore {
  InMemoryFinanceStore({
    List<Transaction> transactions = const [],
    List<CreditCard> cards = const [],
    List<CardBill> bills = const [],
    List<EmiPlan> emis = const [],
    List<SplitGroup> splitGroups = const [],
    List<SplitExpense> splitExpenses = const [],
    List<SplitSettlement> splitSettlements = const [],
  }) {
    _put(_transactions, transactions, (t) => t.id);
    _put(_cards, cards, (c) => c.id);
    _put(_bills, bills, (b) => b.id);
    _put(_emis, emis, (e) => e.id);
    _put(_groups, splitGroups, (g) => g.id);
    _put(_expenses, splitExpenses, (e) => e.id);
    _put(_settlements, splitSettlements, (s) => s.id);
  }

  final _transactions = <String, Transaction>{};
  final _cards = <String, CreditCard>{};
  final _bills = <String, CardBill>{};
  final _emis = <String, EmiPlan>{};
  final _groups = <String, SplitGroup>{};
  final _expenses = <String, SplitExpense>{};
  final _settlements = <String, SplitSettlement>{};

  static void _put<T>(
    Map<String, T> map,
    List<T> items,
    String Function(T) id,
  ) {
    for (final item in items) {
      map[id(item)] = item;
    }
  }

  @override
  Future<List<Transaction>> transactions() async => [..._transactions.values];

  @override
  Future<void> putTransaction(Transaction transaction) async =>
      _transactions[transaction.id] = transaction;

  @override
  Future<void> deleteTransaction(String id) async => _transactions.remove(id);

  @override
  Future<List<CreditCard>> cards() async => [..._cards.values];

  @override
  Future<void> putCard(CreditCard card) async => _cards[card.id] = card;

  @override
  Future<void> deleteCard(String id) async => _cards.remove(id);

  @override
  Future<List<CardBill>> bills() async => [..._bills.values];

  @override
  Future<void> putBill(CardBill bill) async => _bills[bill.id] = bill;

  @override
  Future<void> deleteBill(String id) async => _bills.remove(id);

  @override
  Future<List<EmiPlan>> emis() async => [..._emis.values];

  @override
  Future<void> putEmi(EmiPlan plan) async => _emis[plan.id] = plan;

  @override
  Future<void> deleteEmi(String id) async => _emis.remove(id);

  @override
  Future<List<SplitGroup>> splitGroups() async => [..._groups.values];

  @override
  Future<void> putSplitGroup(SplitGroup group) async =>
      _groups[group.id] = group;

  @override
  Future<void> deleteSplitGroup(String id) async => _groups.remove(id);

  @override
  Future<List<SplitExpense>> splitExpenses() async => [..._expenses.values];

  @override
  Future<void> putSplitExpense(SplitExpense expense) async =>
      _expenses[expense.id] = expense;

  @override
  Future<void> deleteSplitExpense(String id) async => _expenses.remove(id);

  @override
  Future<List<SplitSettlement>> splitSettlements() async => [
    ..._settlements.values,
  ];

  @override
  Future<void> putSplitSettlement(SplitSettlement settlement) async =>
      _settlements[settlement.id] = settlement;

  @override
  Future<void> deleteSplitSettlement(String id) async =>
      _settlements.remove(id);

  @override
  Future<void> putAll({
    List<Transaction> transactions = const [],
    List<CreditCard> cards = const [],
    List<CardBill> bills = const [],
    List<EmiPlan> emis = const [],
    List<SplitGroup> splitGroups = const [],
    List<SplitExpense> splitExpenses = const [],
    List<SplitSettlement> splitSettlements = const [],
  }) async {
    _put(_transactions, transactions, (t) => t.id);
    _put(_cards, cards, (c) => c.id);
    _put(_bills, bills, (b) => b.id);
    _put(_emis, emis, (e) => e.id);
    _put(_groups, splitGroups, (g) => g.id);
    _put(_expenses, splitExpenses, (e) => e.id);
    _put(_settlements, splitSettlements, (s) => s.id);
  }

  @override
  Future<void> clearAll() async {
    _transactions.clear();
    _cards.clear();
    _bills.clear();
    _emis.clear();
    _groups.clear();
    _expenses.clear();
    _settlements.clear();
  }
}
