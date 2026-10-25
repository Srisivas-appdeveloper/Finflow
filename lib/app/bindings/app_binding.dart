import 'package:get/get.dart';

import '../../core/config/app_environment.dart';
import '../../core/motion/motion.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../data/sources/key_value_store.dart';
import '../../data/repositories/card_repository_impl.dart';
import '../../data/repositories/data_management_repository_impl.dart';
import '../../data/repositories/split_repository_impl.dart';
import '../../data/sources/finance_store.dart';
import '../../domain/repositories/card_repository.dart';
import '../../domain/repositories/data_management_repository.dart';
import '../../domain/repositories/split_repository.dart';
import '../services/bill_reminder_service.dart';
import '../services/reminder_scheduler.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/transaction_analytics.dart';
import '../services/theme_controller.dart';

/// Registers app-lifetime dependencies.
///
/// Layers are wired here and nowhere else: UI controllers ask for domain
/// repositories and never learn which storage backs them.
class AppBinding extends Bindings {
  AppBinding({
    required this.environment,
    required this.preferences,
    required this.financeStore,
    this.clock = const AppClock(),
    this.reminders,
  });

  final AppEnvironment environment;
  final KeyValueStore preferences;

  /// On-device financial data (SQLite in the app, in-memory in tests).
  final FinanceStore financeStore;
  final AppClock clock;

  /// Bill reminder scheduler; omitted in tests.
  final ReminderScheduler? reminders;

  @override
  void dependencies() {
    Get.put<AppEnvironment>(environment, permanent: true);
    AppMotion.ambient = environment.ambientMotion;
    AppMotion.intro = environment.launchIntro;
    AppMotion.shimmer = environment.loadingShimmer;
    Get.put<AppClock>(clock, permanent: true);
    Get.put<Formatters>(
      Formatters(locale: environment.locale),
      permanent: true,
    );
    Get.put<TransactionAnalytics>(
      TransactionAnalytics(currencyCode: environment.currencyCode),
      permanent: true,
    );

    Get.put<SettingsRepository>(
      SettingsRepositoryImpl(preferences),
      permanent: true,
    );
    final changes = DataChanges();
    Get.put<DataChanges>(changes, permanent: true);
    Get.put<TransactionRepository>(
      TransactionRepositoryImpl(financeStore, changes),
      permanent: true,
    );
    Get.put<CardRepository>(
      CardRepositoryImpl(financeStore, changes),
      permanent: true,
    );
    Get.put<SplitRepository>(
      SplitRepositoryImpl(financeStore, changes),
      permanent: true,
    );
    Get.put<DataManagementRepository>(
      DataManagementRepositoryImpl(financeStore, changes),
      permanent: true,
    );
    Get.put<ReminderScheduler>(
      reminders ?? const NoopReminderScheduler(),
      permanent: true,
    );

    Get.put<BillReminderService>(
      BillReminderService(
        Get.find<CardRepository>(),
        Get.find<SettingsRepository>(),
        Get.find<ReminderScheduler>(),
        clock,
        Get.find<Formatters>(),
      ),
      permanent: true,
    );

    Get.put<ThemeController>(
      ThemeController(Get.find<SettingsRepository>()),
      permanent: true,
    );
  }
}
