import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/bindings/app_binding.dart';
import 'app/finflow_app.dart';
import 'app/services/reminder_scheduler.dart';
import 'core/config/app_environment.dart';
import 'core/errors/error_reporting.dart';
import 'data/repositories/settings_repository_impl.dart';
import 'data/sources/key_value_store.dart';
import 'data/sources/sqlite_finance_store.dart';
import 'features/shell/startup_failure_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorReporting.install();
  // The bundled Manrope font's licence (SIL OFL) appears on the licences
  // page alongside the package licences.
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL-Manrope.txt');
    yield LicenseEntryWithLineBreaks(const ['Manrope font'], text);
  });
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  try {
    final preferences = await SharedPreferencesStore.create(
      allowList: SettingsRepositoryImpl.keys,
    );
    final financeStore = await SqliteFinanceStore.open();
    final reminders = kIsWeb
        ? const NoopReminderScheduler()
        : await LocalNotificationReminderScheduler.create();

    AppBinding(
      environment: const AppEnvironment(),
      preferences: preferences,
      financeStore: financeStore,
      reminders: reminders,
    ).dependencies();

    runApp(const FinFlowApp());
  } catch (error, stack) {
    // Opening storage failed (e.g. disk full or a corrupted file). Show a
    // clear message instead of a blank screen; the user's data is untouched.
    ErrorReporting.record(error, stack, fatal: true);
    runApp(StartupFailureApp(error: error));
  }
}
