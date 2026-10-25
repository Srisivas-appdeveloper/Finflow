import 'package:get/get.dart';

import '../../domain/repositories/split_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import 'transaction_details_args.dart';
import 'transaction_details_controller.dart';

class TransactionDetailsBinding extends Bindings {
  @override
  void dependencies() {
    final args = Get.arguments is TransactionDetailsArgs
        ? Get.arguments as TransactionDetailsArgs
        : null;
    final id = Get.parameters['id'] ?? args?.transaction?.id ?? '';
    Get.lazyPut(
      () => TransactionDetailsController(
        Get.find<TransactionRepository>(),
        Get.find<SplitRepository>(),
        id: id,
        initial: args?.transaction?.id == id ? args?.transaction : null,
        heroTag: args?.heroTag,
      ),
    );
  }
}
