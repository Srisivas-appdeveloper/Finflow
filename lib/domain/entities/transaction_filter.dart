import 'package:meta/meta.dart';

import 'transaction.dart';
import 'transaction_category.dart';

enum DirectionFilter { all, spending, income }

enum TransactionSort {
  newest('Newest first'),
  oldest('Oldest first'),
  highest('Highest amount'),
  lowest('Lowest amount');

  const TransactionSort(this.label);
  final String label;
}

/// User-selected criteria for the transaction history.
@immutable
class TransactionFilter {
  const TransactionFilter({
    this.query = '',
    this.direction = DirectionFilter.all,
    this.categories = const {},
    this.statuses = const {},
    this.sort = TransactionSort.newest,
  });

  final String query;
  final DirectionFilter direction;
  final Set<TransactionCategory> categories;
  final Set<TransactionStatus> statuses;
  final TransactionSort sort;

  /// Number of criteria set in the advanced filter sheet (for a badge).
  int get advancedCount =>
      (categories.isEmpty ? 0 : 1) +
      (statuses.isEmpty ? 0 : 1) +
      (sort == TransactionSort.newest ? 0 : 1);

  bool get isDefault =>
      query.isEmpty && direction == DirectionFilter.all && advancedCount == 0;

  TransactionFilter copyWith({
    String? query,
    DirectionFilter? direction,
    Set<TransactionCategory>? categories,
    Set<TransactionStatus>? statuses,
    TransactionSort? sort,
  }) {
    return TransactionFilter(
      query: query ?? this.query,
      direction: direction ?? this.direction,
      categories: categories ?? this.categories,
      statuses: statuses ?? this.statuses,
      sort: sort ?? this.sort,
    );
  }

  /// Clears everything except the free-text query.
  TransactionFilter resetAdvanced() => TransactionFilter(query: query);
}
