import 'package:get/get.dart';

import '../../core/utils/clock.dart';
import '../../domain/repositories/card_repository.dart';
import 'cards_controller.dart';

class CardDetailsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => CardDetailsController(
        Get.find<CardRepository>(),
        Get.find<AppClock>(),
        cardId: Get.parameters['id'] ?? '',
      ),
    );
  }
}
