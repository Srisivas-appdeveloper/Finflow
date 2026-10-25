import 'package:flutter/foundation.dart';

/// App-wide configuration.
@immutable
class AppEnvironment {
  const AppEnvironment({
    this.ambientMotion = false,
    this.launchIntro = true,
    this.loadingShimmer = true,
    this.locale = 'en_IN',
    this.currencyCode = 'INR',
  });

  /// Continuous decorative animations (background drift, card sway,
  /// floating orbs). Off: every running animation makes glass panels
  /// re-blur each frame, which costs GPU time and battery.
  final bool ambientMotion;

  /// The cold-start brand intro and the onboarding clips' playback.
  /// Disabled in automated tests.
  final bool launchIntro;

  /// Shimmer sweep on loading skeletons. Disabled in automated tests.
  final bool loadingShimmer;

  /// Locale used for number and currency formatting.
  final String locale;

  /// Default ISO 4217 currency for new amounts.
  final String currencyCode;
}
