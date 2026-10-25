import '../entities/money.dart';
import '../entities/spending_summary.dart';
import '../entities/transaction.dart';
import '../entities/transaction_category.dart';
import '../entities/transaction_filter.dart';

/// Pure business logic over a list of transactions: totals, groupings and
/// filtering. Has no dependency on Flutter, GetX or storage, so it can be
/// unit-tested directly and reused by any data source.
class TransactionAnalytics {
  const TransactionAnalytics({this.currencyCode = 'INR'});

  final String currencyCode;

  Money get _zero => Money.zero(currencyCode: currencyCode);

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  Iterable<Transaction> _counted(Iterable<Transaction> txns) =>
      txns.where((t) => t.affectsBalance);

  /// Transactions that count as income or spending. Movements (transfers
  /// between own accounts, credit card bill payments) are neither, so they
  /// are excluded from summaries; they still appear in history and its
  /// daily nets.
  Iterable<Transaction> _cashFlow(Iterable<Transaction> txns) =>
      _counted(txns).where((t) => !t.category.isMovement);

  /// Sum of what each transaction cost or brought the user: for a split
  /// spend only the user's share counts.
  Money _sum(Iterable<Transaction> txns) =>
      txns.fold(_zero, (sum, t) => sum + t.ownAmount);

  MonthSummary monthSummary(List<Transaction> all, DateTime now) {
    final start = DateTime(now.year, now.month);
    final inMonth = _cashFlow(all)
        .where(
          (t) => !t.occurredAt.isBefore(start) && !t.occurredAt.isAfter(now),
        )
        .toList();
    final spending = _sum(inMonth.where((t) => t.isDebit));
    return MonthSummary(
      month: start,
      income: _sum(inMonth.where((t) => t.isCredit)),
      spending: spending,
      transactionCount: inMonth.length,
      averageDailySpend: spending.divide(now.day),
    );
  }

  /// Spending per day for the [days] days ending on [now], oldest first.
  /// Days without spending are included with a zero amount.
  List<DailySpend> dailySpending(
    List<Transaction> all,
    DateTime now, {
    int days = 7,
  }) {
    final today = _day(now);
    final totals = <DateTime, int>{
      for (var i = days - 1; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i): 0,
    };
    for (final t in _cashFlow(all).where((t) => t.isDebit)) {
      final key = _day(t.occurredAt);
      if (totals.containsKey(key)) {
        totals[key] = totals[key]! + t.ownAmount.minor;
      }
    }
    return [
      for (final e in totals.entries)
        DailySpend(e.key, Money(e.value, currencyCode: currencyCode)),
    ];
  }

  /// Spending by category since [from], largest first. Categories beyond
  /// [limit] are folded into one bucket with a `null` category.
  List<CategorySpend> spendingByCategory(
    List<Transaction> all, {
    required DateTime from,
    int? limit,
  }) {
    final debits = _cashFlow(
      all,
    ).where((t) => t.isDebit && !t.occurredAt.isBefore(from)).toList();
    final total = _sum(debits);
    if (total.isZero) return const [];

    final byCategory = <TransactionCategory, (int, int)>{};
    for (final t in debits) {
      final (minor, count) = byCategory[t.category] ?? (0, 0);
      byCategory[t.category] = (minor + t.ownAmount.minor, count + 1);
    }
    final ranked = byCategory.entries.toList()
      ..sort((a, b) => b.value.$1.compareTo(a.value.$1));

    CategorySpend toSpend(TransactionCategory? key, int minor, int count) =>
        CategorySpend(
          category: key,
          amount: Money(minor, currencyCode: currencyCode),
          share: minor / total.minor,
          count: count,
        );

    if (limit == null || ranked.length <= limit) {
      return [for (final e in ranked) toSpend(e.key, e.value.$1, e.value.$2)];
    }
    final head = ranked.take(limit - 1);
    final tail = ranked.skip(limit - 1);
    return [
      for (final e in head) toSpend(e.key, e.value.$1, e.value.$2),
      toSpend(
        null,
        tail.fold(0, (s, e) => s + e.value.$1),
        tail.fold(0, (s, e) => s + e.value.$2),
      ),
    ];
  }

  /// Payees the user spent the most with since [from].
  List<PayeeSpend> topPayees(
    List<Transaction> all, {
    required DateTime from,
    int limit = 5,
  }) {
    final totals = <String, (int, int)>{};
    for (final t in _cashFlow(
      all,
    ).where((t) => t.isDebit && !t.occurredAt.isBefore(from))) {
      final (minor, count) = totals[t.title] ?? (0, 0);
      totals[t.title] = (minor + t.ownAmount.minor, count + 1);
    }
    final ranked = totals.entries.toList()
      ..sort((a, b) => b.value.$1.compareTo(a.value.$1));
    return [
      for (final e in ranked.take(limit))
        PayeeSpend(
          e.key,
          Money(e.value.$1, currencyCode: currencyCode),
          e.value.$2,
        ),
    ];
  }

  DashboardSummary dashboard(List<Transaction> all, DateTime now) {
    final today = _day(now);
    return DashboardSummary(
      month: monthSummary(all, now),
      lastSevenDays: dailySpending(all, now),
      topCategories: spendingByCategory(
        all,
        from: DateTime(now.year, now.month),
        limit: 4,
      ),
      recent: all.take(5).toList(),
      spentToday: _sum(
        _cashFlow(all).where((t) => t.isDebit && _day(t.occurredAt) == today),
      ),
      pendingCount: all
          .where((t) => t.status == TransactionStatus.pending)
          .length,
    );
  }

  /// Applies [filter] to [all] and returns the matching, sorted list.
  List<Transaction> apply(List<Transaction> all, TransactionFilter filter) {
    final query = filter.query.trim().toLowerCase();
    final result = all.where((t) {
      if (filter.direction == DirectionFilter.spending && !t.isDebit) {
        return false;
      }
      if (filter.direction == DirectionFilter.income && !t.isCredit) {
        return false;
      }
      if (filter.categories.isNotEmpty &&
          !filter.categories.contains(t.category)) {
        return false;
      }
      if (filter.statuses.isNotEmpty && !filter.statuses.contains(t.status)) {
        return false;
      }
      if (query.isNotEmpty &&
          !t.title.toLowerCase().contains(query) &&
          !t.category.label.toLowerCase().contains(query) &&
          !(t.note?.toLowerCase().contains(query) ?? false)) {
        return false;
      }
      return true;
    }).toList();

    switch (filter.sort) {
      case TransactionSort.newest:
        result.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      case TransactionSort.oldest:
        result.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
      case TransactionSort.highest:
        result.sort((a, b) => b.amount.compareTo(a.amount));
      case TransactionSort.lowest:
        result.sort((a, b) => a.amount.compareTo(b.amount));
    }
    return result;
  }

  /// Splits an already-sorted list into day sections. Lists sorted by amount
  /// are returned as a single ungrouped section.
  List<TransactionDayGroup> groupByDay(
    List<Transaction> sorted,
    TransactionSort sort,
  ) {
    if (sorted.isEmpty) return const [];
    if (sort == TransactionSort.highest || sort == TransactionSort.lowest) {
      return [
        TransactionDayGroup(day: null, transactions: sorted, net: net(sorted)),
      ];
    }
    final groups = <TransactionDayGroup>[];
    var bucket = <Transaction>[];
    DateTime? current;
    void flush() {
      if (bucket.isEmpty) return;
      groups.add(
        TransactionDayGroup(
          day: current,
          transactions: bucket,
          net: net(bucket),
        ),
      );
    }

    for (final t in sorted) {
      final day = _day(t.occurredAt);
      if (day != current) {
        flush();
        bucket = [];
        current = day;
      }
      bucket.add(t);
    }
    flush();
    return groups;
  }

  /// Net of counted transactions (credits minus debits).
  Money net(Iterable<Transaction> txns) =>
      _counted(txns).fold(_zero, (sum, t) => sum + t.signedAmount);
}
