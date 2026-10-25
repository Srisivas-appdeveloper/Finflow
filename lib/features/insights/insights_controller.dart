import 'dart:async';
import 'dart:math' as math;

import 'package:get/get.dart';

import '../../core/state/view_state.dart';
import '../../core/utils/clock.dart';
import '../../domain/entities/spending_summary.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/transaction_analytics.dart';

class InsightsData {
  const InsightsData({
    required this.month,
    required this.previousPeriod,
    required this.categories,
    required this.payees,
  });

  final MonthSummary month;

  /// Last month up to the same day, for a like-for-like comparison.
  final MonthSummary previousPeriod;
  final List<CategorySpend> categories;
  final List<PayeeSpend> payees;

  /// Fractional change in spending vs [previousPeriod], or `null` if there
  /// is nothing to compare with.
  double? get spendingChange {
    final before = previousPeriod.spending.minor;
    if (before == 0) return null;
    return (month.spending.minor - before) / before;
  }
}

class InsightsController extends GetxController {
  InsightsController(this._repository, this._analytics, this._clock);

  final TransactionRepository _repository;
  final TransactionAnalytics _analytics;
  final AppClock _clock;

  final state = Rx<ViewState<InsightsData>>(const ViewLoading());
  StreamSubscription<void>? _changes;

  @override
  void onInit() {
    super.onInit();
    load();
    _changes = _repository.changes.listen((_) => load(showLoading: false));
  }

  @override
  void onClose() {
    _changes?.cancel();
    super.onClose();
  }

  Future<void> load({bool showLoading = true}) async {
    if (showLoading) state.value = const ViewLoading();
    try {
      final all = await _repository.getAll();
      if (all.isEmpty) {
        state.value = const ViewEmpty();
        return;
      }
      final now = _clock.now();
      final monthStart = DateTime(now.year, now.month);
      final lastDayPrev = DateTime(now.year, now.month, 0).day;
      final samePointLastMonth = DateTime(
        now.year,
        now.month - 1,
        math.min(now.day, lastDayPrev),
        now.hour,
        now.minute,
      );
      state.value = ViewData(
        InsightsData(
          month: _analytics.monthSummary(all, now),
          previousPeriod: _analytics.monthSummary(all, samePointLastMonth),
          categories: _analytics.spendingByCategory(all, from: monthStart),
          payees: _analytics.topPayees(all, from: monthStart),
        ),
      );
    } catch (_) {
      state.value = const ViewError(
        'We couldn\'t load your insights. Please try again.',
      );
    }
  }
}
