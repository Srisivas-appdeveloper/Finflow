import 'package:get/get.dart';

import '../../core/config/app_environment.dart';
import '../../core/utils/clock.dart';
import '../../domain/repositories/transaction_repository.dart';
import 'transaction_form_controller.dart';

class TransactionFormBinding extends Bindings {
  @override
  void dependencies() {
    final id = Get.parameters['id'];
    Get.lazyPut(
      () => TransactionFormController(
        Get.find<TransactionRepository>(),
        Get.find<AppClock>(),
        editingId: id == null || id.isEmpty ? null : id,
        currencyCode: Get.find<AppEnvironment>().currencyCode,
      ),
    );
  }
}
