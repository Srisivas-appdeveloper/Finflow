import 'package:get/get.dart';

import '../../app/services/bill_reminder_service.dart';
import '../../core/config/app_environment.dart';
import '../../core/utils/clock.dart';
import '../../domain/repositories/card_repository.dart';
import '../../domain/repositories/data_management_repository.dart';
import '../../domain/repositories/split_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/transaction_analytics.dart';
import '../home/home_controller.dart';
import '../cards/cards_controller.dart';
import '../insights/insights_controller.dart';
import '../profile/profile_controller.dart';
import '../transactions/transactions_controller.dart';
import 'shell_controller.dart';

class ShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(ShellController.new);
    Get.lazyPut(
      () => HomeController(
        Get.find<TransactionRepository>(),
        Get.find<TransactionAnalytics>(),
        Get.find<AppClock>(),
        Get.find<SplitRepository>(),
        currencyCode: Get.find<AppEnvironment>().currencyCode,
      ),
    );
    Get.lazyPut(
      () => TransactionsController(
        Get.find<TransactionRepository>(),
        Get.find<TransactionAnalytics>(),
      ),
    );
    Get.lazyPut(
      () => InsightsController(
        Get.find<TransactionRepository>(),
        Get.find<TransactionAnalytics>(),
        Get.find<AppClock>(),
      ),
    );
    Get.lazyPut(
      () => CardsController(
        Get.find<CardRepository>(),
        Get.find<AppClock>(),
        currencyCode: Get.find<AppEnvironment>().currencyCode,
      ),
    );
    Get.lazyPut(
      () => ProfileController(
        Get.find<DataManagementRepository>(),
        Get.find<BillReminderService>(),
        Get.find<AppClock>(),
      ),
    );
  }
}
