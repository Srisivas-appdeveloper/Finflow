import 'dart:convert';

import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/services/bill_reminder_service.dart';
import '../../core/utils/clock.dart';
import '../../domain/repositories/data_management_repository.dart';

class ProfileController extends GetxController {
  ProfileController(this._data, this._reminders, this._clock);

  final DataManagementRepository _data;
  final BillReminderService _reminders;
  final AppClock _clock;

  final busy = false.obs;
  final version = ''.obs;

  RxBool get remindersEnabled => _reminders.enabled;

  @override
  void onInit() {
    super.onInit();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      version.value = '${info.version} (${info.buildNumber})';
    } catch (_) {
      // Not available in tests.
    }
  }

  /// Returns the resulting state (stays off if permission is refused).
  Future<bool> setReminders(bool value) => _reminders.setEnabled(value);

  /// Shares all transactions as a CSV file. Returns false on failure.
  Future<bool> exportCsv() async {
    busy.value = true;
    try {
      final csv = await _data.exportTransactionsCsv();
      final stamp = _clock.now().toIso8601String().substring(0, 10);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(utf8.encode(csv), mimeType: 'text/csv')],
          fileNameOverrides: ['finflow-transactions-$stamp.csv'],
          subject: 'FinFlow transactions',
        ),
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      busy.value = false;
    }
  }

  Future<void> clearAll() async {
    busy.value = true;
    try {
      await _data.clearAll();
    } finally {
      busy.value = false;
    }
  }
}
