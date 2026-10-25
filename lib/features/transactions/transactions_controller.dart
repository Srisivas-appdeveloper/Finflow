import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/state/view_state.dart';
import '../../domain/entities/money.dart';
import '../../domain/entities/spending_summary.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_filter.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/transaction_analytics.dart';

/// Result of applying the current filter.
class TransactionResults {
  const TransactionResults({
    required this.groups,
    required this.count,
    required this.net,
  });

  final List<TransactionDayGroup> groups;
  final int count;
  final Money net;

  bool get isEmpty => count == 0;
}

class TransactionsController extends GetxController {
  TransactionsController(this._repository, this._analytics);

  static const searchDebounce = Duration(milliseconds: 300);

  final TransactionRepository _repository;
  final TransactionAnalytics _analytics;

  final filter = const TransactionFilter().obs;

  /// [ViewEmpty] means there are no transactions at all; a filter that
  /// matches nothing yields [ViewData] with empty results.
  final state = Rx<ViewState<TransactionResults>>(const ViewLoading());

  final searchController = TextEditingController();
  final _query = ''.obs;

  List<Transaction> _all = const [];
  StreamSubscription<void>? _changes;
  Worker? _searchWorker;

  @override
  void onInit() {
    super.onInit();
    _searchWorker = debounce<String>(
      _query,
      (q) => _setFilter(filter.value.copyWith(query: q)),
      time: searchDebounce,
    );
    load();
    _changes = _repository.changes.listen((_) => load(showLoading: false));
  }

  @override
  void onClose() {
    _changes?.cancel();
    _searchWorker?.dispose();
    searchController.dispose();
    super.onClose();
  }

  Future<void> load({bool showLoading = true}) async {
    if (showLoading) state.value = const ViewLoading();
    try {
      _all = await _repository.getAll();
      _recompute();
    } catch (_) {
      state.value = const ViewError(
        'We couldn\'t load your transactions. Please try again.',
      );
    }
  }

  void onSearchChanged(String value) => _query.value = value;

  void setDirection(DirectionFilter direction) =>
      _setFilter(filter.value.copyWith(direction: direction));

  /// Applies criteria chosen in the filter sheet, keeping the search text.
  void applyAdvanced(TransactionFilter value) =>
      _setFilter(value.copyWith(query: filter.value.query));

  /// How many transactions [draft] would show, keeping the current search.
  /// Lets the filter sheet preview its result before applying.
  int previewCount(TransactionFilter draft) =>
      _analytics.apply(_all, draft.copyWith(query: filter.value.query)).length;

  void clearAll() {
    searchController.clear();
    _query.value = '';
    _setFilter(const TransactionFilter());
  }

  void _setFilter(TransactionFilter value) {
    filter.value = value;
    _recompute();
  }

  void _recompute() {
    if (_all.isEmpty) {
      state.value = const ViewEmpty();
      return;
    }
    final f = filter.value;
    final matches = _analytics.apply(_all, f);
    state.value = ViewData(
      TransactionResults(
        groups: _analytics.groupByDay(matches, f.sort),
        count: matches.length,
        net: _analytics.net(matches),
      ),
    );
  }
}
