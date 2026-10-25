enum AppThemePreference { system, light, dark }

/// User preferences persisted across launches.
abstract interface class SettingsRepository {
  AppThemePreference get themePreference;
  Future<void> setThemePreference(AppThemePreference value);

  /// Whether the user has finished (or skipped) onboarding.
  bool get onboardingComplete;
  Future<void> setOnboardingComplete(bool value);

  /// Whether bill due-date reminders are on. Off until the user opts in.
  bool get remindersEnabled;
  Future<void> setRemindersEnabled(bool value);
}
