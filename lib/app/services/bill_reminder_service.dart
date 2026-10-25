import 'dart:async';

import 'package:get/get.dart';

import '../../core/utils/clock.dart';
import '../../core/utils/formatters.dart';
import '../../domain/repositories/card_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/services/bill_reminders.dart';
import 'reminder_scheduler.dart';

/// Keeps scheduled bill reminders in step with the stored bills: whenever
/// data changes (a bill added, a payment recorded) the schedule is rebuilt.
class BillReminderService extends GetxService {
  BillReminderService(
    this._cards,
    this._settings,
    this._scheduler,
    this._clock,
    this._formatters,
  );

  final CardRepository _cards;
  final SettingsRepository _settings;
  final ReminderScheduler _scheduler;
  final AppClock _clock;
  final Formatters _formatters;

  late final enabled = _settings.remindersEnabled.obs;
  StreamSubscription<void>? _changes;

  @override
  void onInit() {
    super.onInit();
    _changes = _cards.changes.listen((_) => sync());
    sync();
  }

  @override
  void onClose() {
    _changes?.cancel();
    super.onClose();
  }

  /// Turns reminders on (asking for permission) or off. Returns the
  /// resulting state, which stays off if permission is refused.
  Future<bool> setEnabled(bool value) async {
    if (value && !await _scheduler.requestPermission()) {
      value = false;
    }
    enabled.value = value;
    await _settings.setRemindersEnabled(value);
    await sync();
    return value;
  }

  Future<void> sync() async {
    try {
      if (!enabled.value) {
        await _scheduler.cancelAll();
        return;
      }
      final cards = {for (final c in await _cards.cards()) c.id: c};
      final planner = BillReminderPlanner(
        formatAmount: (bill) => _formatters.money(bill.remaining),
      );
      await _scheduler.replaceAll(
        planner.plan(await _cards.bills(), cards, _clock.now()),
      );
    } catch (_) {
      // Reminders must never break the app; the next change retries.
    }
  }
}
