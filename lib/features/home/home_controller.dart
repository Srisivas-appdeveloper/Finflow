import 'dart:async';

import 'package:get/get.dart';

import '../../core/state/view_state.dart';
import '../../core/utils/clock.dart';
import '../../domain/entities/spending_summary.dart';
import '../../domain/repositories/split_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/transaction_analytics.dart';
import '../split/split_controllers.dart';

class HomeController extends GetxController {
  HomeController(
    this._repository,
    this._analytics,
    this._clock,
    this._splits, {
    required this.currencyCode,
  });

  final TransactionRepository _repository;
  final TransactionAnalytics _analytics;
  final AppClock _clock;
  final SplitRepository _splits;
  final String currencyCode;

  final state = Rx<ViewState<DashboardSummary>>(const ViewLoading());

  /// Split balances for the Home entry card; null until loaded.
  final split = Rxn<SplitOverview>();
  StreamSubscription<void>? _changes;

  DateTime get now => _clock.now();

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
      state.value = all.isEmpty
          ? const ViewEmpty()
          : ViewData(_analytics.dashboard(all, now));
      split.value = SplitOverview(
        ledgers: await loadLedgers(_splits, currencyCode),
        month: _analytics.monthSummary(all, now),
        now: now,
        currencyCode: currencyCode,
      );
    } catch (_) {
      state.value = const ViewError(
        'We couldn\'t load your transactions. Please try again.',
      );
    }
  }
}
