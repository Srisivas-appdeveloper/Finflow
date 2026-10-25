import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/repositories/settings_repository.dart';

/// App-wide theme mode, persisted through [SettingsRepository].
class ThemeController extends GetxController {
  ThemeController(this._settings);

  final SettingsRepository _settings;

  late final Rx<AppThemePreference> preference = _settings.themePreference.obs;

  ThemeMode get themeMode => switch (preference.value) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  };

  Future<void> setPreference(AppThemePreference value) async {
    if (value == preference.value) return;
    preference.value = value;
    Get.changeThemeMode(themeMode);
    await _settings.setThemePreference(value);
  }
}
