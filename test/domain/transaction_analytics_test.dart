import 'package:finflow/domain/entities/money.dart';
import 'package:finflow/domain/entities/transaction.dart';
import 'package:finflow/domain/entities/transaction_category.dart';
import 'package:finflow/domain/entities/transaction_filter.dart';
import 'package:finflow/domain/services/transaction_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction txn(
  String id,
  DateTime at,
  int minor, {
  bool credit = false,
  TransactionCategory category = TransactionCategory.dining,
  TransactionStatus status = TransactionStatus.completed,
  String? title,
}) {
  return Transaction(
    id: id,
    title: title ?? 'Payee $id',
    amount: Money(minor),
    direction: credit
        ? TransactionDirection.credit
        : TransactionDirection.debit,
    category: category,
    status: status,
    occurredAt: at,
    paymentMethod: PaymentMethod.upi,
  );
}

void main() {
  const analytics = TransactionAnalytics();
  final now = DateTime(2026, 10, 24, 18);

  final data = [
    txn('1', DateTime(2026, 10, 24, 9), 50000),
    txn(
      '2',
      DateTime(2026, 10, 23, 9),
      20000,
      category: TransactionCategory.transport,
    ),
    txn(
      '3',
      DateTime(2026, 10, 1, 9),
      8500000,
      credit: true,
      category: TransactionCategory.salary,
    ),
    txn(
      '4',
      DateTime(2026, 10, 22, 9),
      99900,
      status: TransactionStatus.failed,
      category: TransactionCategory.shopping,
    ),
    txn(
      '5',
      DateTime(2026, 9, 30, 9),
      70000,
      category: TransactionCategory.groceries,
    ),
    txn(
      '6',
      DateTime(2026, 10, 20, 9),
      30000,
      category: TransactionCategory.groceries,
      status: TransactionStatus.pending,
    ),
  ];

  test('month summary counts only this month and ignores failed', () {
    final m = analytics.monthSummary(data, now);
    expect(m.income.minor, 8500000);
    expect(m.spending.minor, 50000 + 20000 + 30000);
    expect(m.net.minor, 8500000 - 100000);
    expect(m.transactionCount, 4);
    expect(m.averageDailySpend.minor, (100000 / 24).round());
  });

  test('daily spending covers 7 days with zeros, oldest first', () {
    final days = analytics.dailySpending(data, now);
    expect(days, hasLength(7));
    expect(days.first.day, DateTime(2026, 10, 18));
    expect(days.last.day, DateTime(2026, 10, 24));
    expect(days.last.amount.minor, 50000);
    expect(days[5].amount.minor, 20000);
    // Failed payment on the 22nd does not count.
    expect(days[4].amount.minor, 0);
  });

  test('category breakdown ranks and folds the tail', () {
    final all = analytics.spendingByCategory(data, from: DateTime(2026, 10));
    expect(all.map((c) => c.category), [
      TransactionCategory.dining,
      TransactionCategory.groceries,
      TransactionCategory.transport,
    ]);
    expect(all.fold<double>(0, (s, c) => s + c.share), closeTo(1, 1e-9));

    final folded = analytics.spendingByCategory(
      data,
      from: DateTime(2026, 10),
      limit: 2,
    );
    expect(folded, hasLength(2));
    expect(folded.last.category, isNull);
    expect(folded.last.amount.minor, 50000);
  });

  test('filter by direction, category, status and query', () {
    expect(
      analytics
          .apply(
            data,
            const TransactionFilter(direction: DirectionFilter.income),
          )
          .map((t) => t.id),
      ['3'],
    );
    expect(
      analytics
          .apply(
            data,
            const TransactionFilter(
              categories: {TransactionCategory.groceries},
            ),
          )
          .map((t) => t.id),
      ['6', '5'],
    );
    expect(
      analytics
          .apply(
            data,
            const TransactionFilter(statuses: {TransactionStatus.failed}),
          )
          .map((t) => t.id),
      ['4'],
    );
    expect(
      analytics
          .apply(data, const TransactionFilter(query: 'payee 2'))
          .map((t) => t.id),
      ['2'],
    );
    expect(
      analytics
          .apply(data, const TransactionFilter(query: 'TRANSPORT'))
          .map((t) => t.id),
      ['2'],
    );
  });

  test('sorting', () {
    final highest = analytics.apply(
      data,
      const TransactionFilter(sort: TransactionSort.highest),
    );
    expect(highest.first.id, '3');
    final oldest = analytics.apply(
      data,
      const TransactionFilter(sort: TransactionSort.oldest),
    );
    expect(oldest.first.id, '5');
  });

  test('groups by day for date sorts, single group for amount sorts', () {
    final sorted = analytics.apply(data, const TransactionFilter());
    final groups = analytics.groupByDay(sorted, TransactionSort.newest);
    expect(groups.first.day, DateTime(2026, 10, 24));
    expect(groups.length, 6);
    expect(groups.first.net.minor, -50000);

    final byAmount = analytics.groupByDay(sorted, TransactionSort.highest);
    expect(byAmount, hasLength(1));
    expect(byAmount.single.day, isNull);
  });

  test('dashboard summary', () {
    final d = analytics.dashboard(data, now);
    expect(d.spentToday.minor, 50000);
    expect(d.pendingCount, 1);
    expect(d.recent, hasLength(5));
    expect(d.lastSevenDaysTotal.minor, 50000 + 20000 + 30000);
  });

  test('empty input yields empty results', () {
    expect(analytics.spendingByCategory(const [], from: now), isEmpty);
    expect(analytics.groupByDay(const [], TransactionSort.newest), isEmpty);
    expect(analytics.monthSummary(const [], now).spending.isZero, isTrue);
  });

  test('transfers are excluded from income and spending summaries', () {
    final withTransfer = [
      ...data,
      txn(
        't',
        DateTime(2026, 10, 24, 10),
        1000000,
        category: TransactionCategory.transfer,
      ),
    ];
    final m = analytics.monthSummary(withTransfer, now);
    expect(m.spending.minor, 100000);
    expect(
      analytics
          .spendingByCategory(withTransfer, from: DateTime(2026, 10))
          .map((c) => c.category),
      isNot(contains(TransactionCategory.transfer)),
    );
    expect(analytics.dailySpending(withTransfer, now).last.amount.minor, 50000);
    // Still a real money movement in the history's daily net.
    final groups = analytics.groupByDay(
      analytics.apply(withTransfer, const TransactionFilter()),
      TransactionSort.newest,
    );
    expect(groups.first.net.minor, -1050000);
  });
}
