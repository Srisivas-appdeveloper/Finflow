import 'package:get/get.dart';

import '../../core/config/app_environment.dart';
import '../../core/utils/clock.dart';
import '../../domain/repositories/split_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/transaction_analytics.dart';
import 'split_controllers.dart';
import 'split_expense_form_controller.dart';

class SplitBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => SplitOverviewController(
        Get.find<SplitRepository>(),
        Get.find<TransactionRepository>(),
        Get.find<TransactionAnalytics>(),
        Get.find<AppClock>(),
        currencyCode: Get.find<AppEnvironment>().currencyCode,
      ),
    );
  }
}

class SplitGroupBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => SplitGroupController(
        Get.find<SplitRepository>(),
        Get.find<AppClock>(),
        groupId: Get.parameters['id'] ?? '',
        currencyCode: Get.find<AppEnvironment>().currencyCode,
      ),
    );
  }
}

class SplitExpenseFormBinding extends Bindings {
  @override
  void dependencies() {
    String? param(String key) {
      final v = Get.parameters[key];
      return v == null || v.isEmpty ? null : v;
    }

    Get.lazyPut(
      () => SplitExpenseFormController(
        Get.find<SplitRepository>(),
        Get.find<TransactionRepository>(),
        Get.find<AppClock>(),
        groupId: param('group') ?? '',
        expenseId: param('expense'),
        transactionId: param('transaction'),
        currencyCode: Get.find<AppEnvironment>().currencyCode,
      ),
    );
  }
}
