import 'dart:async';

import 'package:get/get.dart';

import '../../core/state/view_state.dart';
import '../../core/utils/clock.dart';
import '../../domain/entities/money.dart';
import '../../domain/entities/spending_summary.dart';
import '../../domain/entities/split.dart';
import '../../domain/repositories/split_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/split_ledger.dart';
import '../../domain/services/transaction_analytics.dart';

/// Everything the Split page shows.
class SplitOverview {
  const SplitOverview({
    required this.ledgers,
    required this.month,
    required this.now,
    required this.currencyCode,
  });

  /// One ledger per group, oldest group first.
  final List<SplitLedger> ledgers;

  /// This month's income and the user's own spending.
  final MonthSummary month;
  final DateTime now;
  final String currencyCode;

  Money get _zero => Money.zero(currencyCode: currencyCode);

  /// What others owe the user, across groups.
  Money get owedToYou => ledgers
      .map((l) => l.yourBalance)
      .where((b) => b.isPositive)
      .fold(_zero, (a, b) => a + b);

  /// What the user owes others, across groups (positive).
  Money get youOwe => ledgers
      .map((l) => l.yourBalance)
      .where((b) => b.isNegative)
      .fold(_zero, (a, b) => a - b);
}

/// Loads every group's ledger.
Future<List<SplitLedger>> loadLedgers(
  SplitRepository repository,
  String currencyCode,
) async {
  final expenses = await repository.expenses();
  final settlements = await repository.settlements();
  return [
    for (final g in await repository.groups())
      SplitLedger(
        group: g,
        expenses: expenses,
        settlements: settlements,
        currencyCode: currencyCode,
      ),
  ];
}

class SplitOverviewController extends GetxController {
  SplitOverviewController(
    this._splits,
    this._transactions,
    this._analytics,
    this._clock, {
    required this.currencyCode,
  });

  final SplitRepository _splits;
  final TransactionRepository _transactions;
  final TransactionAnalytics _analytics;
  final AppClock _clock;
  final String currencyCode;

  final state = Rx<ViewState<SplitOverview>>(const ViewLoading());
  StreamSubscription<void>? _changes;

  @override
  void onInit() {
    super.onInit();
    load();
    _changes = _splits.changes.listen((_) => load(showLoading: false));
  }

  @override
  void onClose() {
    _changes?.cancel();
    super.onClose();
  }

  Future<void> load({bool showLoading = true}) async {
    if (showLoading) state.value = const ViewLoading();
    try {
      final now = _clock.now();
      state.value = ViewData(
        SplitOverview(
          ledgers: await loadLedgers(_splits, currencyCode),
          month: _analytics.monthSummary(await _transactions.getAll(), now),
          now: now,
          currencyCode: currencyCode,
        ),
      );
    } catch (_) {
      state.value = const ViewError(
        'We couldn\'t load your groups. Please try again.',
      );
    }
  }
}

/// One group: balances, settle-up suggestions and its history.
class SplitGroupController extends GetxController {
  SplitGroupController(
    this._splits,
    this._clock, {
    required this.groupId,
    required this.currencyCode,
  });

  final SplitRepository _splits;
  final AppClock _clock;
  final String groupId;
  final String currencyCode;

  final state = Rx<ViewState<SplitLedger>>(const ViewLoading());
  StreamSubscription<void>? _changes;

  /// True when the group no longer exists (e.g. deleted).
  final notFound = false.obs;

  DateTime get now => _clock.now();

  SplitGroup? get group => switch (state.value) {
    ViewData(:final data) => data.group,
    _ => null,
  };

  @override
  void onInit() {
    super.onInit();
    load();
    _changes = _splits.changes.listen((_) => load(showLoading: false));
  }

  @override
  void onClose() {
    _changes?.cancel();
    super.onClose();
  }

  Future<void> load({bool showLoading = true}) async {
    if (showLoading) state.value = const ViewLoading();
    try {
      final group = await _splits.group(groupId);
      state.value = ViewData(
        SplitLedger(
          group: group,
          expenses: await _splits.expenses(groupId: groupId),
          settlements: await _splits.settlements(groupId: groupId),
          currencyCode: currencyCode,
        ),
      );
    } on SplitNotFoundException {
      notFound.value = true;
      state.value = const ViewError('This group no longer exists.');
    } catch (_) {
      state.value = const ViewError(
        'We couldn\'t load this group. Please try again.',
      );
    }
  }
}
