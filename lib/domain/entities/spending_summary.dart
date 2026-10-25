import 'package:meta/meta.dart';

import 'money.dart';
import 'transaction.dart';
import 'transaction_category.dart';

/// Totals for a calendar month, derived from recorded transactions only.
@immutable
class MonthSummary {
  const MonthSummary({
    required this.month,
    required this.income,
    required this.spending,
    required this.transactionCount,
    required this.averageDailySpend,
  });

  /// First day of the month.
  final DateTime month;
  final Money income;

  /// Positive amount spent.
  final Money spending;
  final int transactionCount;
  final Money averageDailySpend;

  Money get net => income - spending;
}

@immutable
class DailySpend {
  const DailySpend(this.day, this.amount);
  final DateTime day;
  final Money amount;
}

@immutable
class CategorySpend {
  const CategorySpend({
    required this.category,
    required this.amount,
    required this.share,
    required this.count,
  });

  /// `null` represents the folded "everything else" bucket.
  final TransactionCategory? category;
  final Money amount;

  /// Fraction of total spending, 0..1.
  final double share;
  final int count;
}

@immutable
class PayeeSpend {
  const PayeeSpend(this.name, this.amount, this.count);
  final String name;
  final Money amount;
  final int count;
}

/// Everything the home dashboard shows, computed in one pass.
@immutable
class DashboardSummary {
  const DashboardSummary({
    required this.month,
    required this.lastSevenDays,
    required this.topCategories,
    required this.recent,
    required this.spentToday,
    required this.pendingCount,
  });

  final MonthSummary month;
  final List<DailySpend> lastSevenDays;
  final List<CategorySpend> topCategories;
  final List<Transaction> recent;
  final Money spentToday;
  final int pendingCount;

  Money get lastSevenDaysTotal => lastSevenDays.fold(
    Money.zero(currencyCode: month.income.currencyCode),
    (sum, d) => sum + d.amount,
  );
}

/// Transactions sharing a calendar day, for sectioned lists.
@immutable
class TransactionDayGroup {
  const TransactionDayGroup({
    required this.day,
    required this.transactions,
    required this.net,
  });

  /// `null` when the list is not sorted by date and is shown ungrouped.
  final DateTime? day;
  final List<Transaction> transactions;
  final Money net;
}
