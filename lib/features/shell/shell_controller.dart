import 'package:get/get.dart';

import 'app_tab.dart';

class ShellController extends GetxController {
  final current = AppTab.home.obs;

  void select(AppTab tab) => current.value = tab;

  /// Handles system back while the shell is the top route. Returns `true`
  /// if it was consumed (by returning to Home) and the app should stay open.
  bool handleBack() {
    if (current.value == AppTab.home) return false;
    current.value = AppTab.home;
    return true;
  }
}
