import '../../domain/repositories/settings_repository.dart';
import '../sources/key_value_store.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._store);

  static const themeKey = 'settings.theme';
  static const onboardingKey = 'settings.onboarding';
  static const remindersKey = 'settings.reminders';

  /// Every key this repository reads or writes.
  static const keys = {themeKey, onboardingKey, remindersKey};

  final KeyValueStore _store;

  @override
  AppThemePreference get themePreference {
    final raw = _store.getString(themeKey);
    return AppThemePreference.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => AppThemePreference.system,
    );
  }

  @override
  Future<void> setThemePreference(AppThemePreference value) =>
      _store.setString(themeKey, value.name);

  @override
  bool get onboardingComplete => _store.getString(onboardingKey) == 'done';

  @override
  Future<void> setOnboardingComplete(bool value) =>
      _store.setString(onboardingKey, value ? 'done' : 'pending');

  @override
  bool get remindersEnabled => _store.getString(remindersKey) == 'on';

  @override
  Future<void> setRemindersEnabled(bool value) =>
      _store.setString(remindersKey, value ? 'on' : 'off');
}
