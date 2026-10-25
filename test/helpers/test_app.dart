import 'package:finflow/app/bindings/app_binding.dart';
import 'package:finflow/app/finflow_app.dart';
import 'package:finflow/core/config/app_environment.dart';
import 'package:finflow/core/utils/clock.dart';
import 'package:finflow/data/repositories/settings_repository_impl.dart';
import 'package:finflow/data/sources/key_value_store.dart';
import 'package:finflow/data/sources/finance_store.dart';
import 'package:finflow/features/shell/glass_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../fixtures/sample_data.dart';

/// Fixed "now" so dashboards and date labels are stable.
final testNow = DateTime(2026, 10, 24, 18, 30);

/// In-memory store pre-filled with the test fixture data.
InMemoryFinanceStore sampleStore() {
  final bundle = const SampleDataGenerator().generate(testNow);
  return InMemoryFinanceStore(
    transactions: bundle.transactions,
    cards: bundle.cards,
    bills: bundle.bills,
    emis: bundle.emis,
  );
}

/// Boots the full app with in-memory dependencies. Uses the fixture data
/// unless [financeStore] is given (pass an empty store for first-run tests).
Future<InMemoryStore> pumpFinFlow(
  WidgetTester tester, {
  Size size = const Size(412, 915),
  double textScale = 1,
  FinanceStore? financeStore,
  Map<String, String>? prefs,
  bool settle = true,
}) async {
  Get.reset();
  Get.testMode = true;

  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    Get.reset();
  });

  final store = InMemoryStore({
    // Existing users: onboarding already seen unless a test says otherwise.
    SettingsRepositoryImpl.onboardingKey: 'done',
    ...?prefs,
  });
  AppBinding(
    environment: const AppEnvironment(
      launchIntro: false,
      loadingShimmer: false,
    ),
    preferences: store,
    financeStore: financeStore ?? sampleStore(),
    clock: AppClock(() => testNow),
  ).dependencies();

  await tester.pumpWidget(const FinFlowApp());
  if (settle) await tester.pumpAndSettle();
  return store;
}

/// A bottom navigation destination's label.
Finder navLabel(String label) =>
    find.descendant(of: find.byType(GlassNavBar), matching: find.text(label));

/// Taps a bottom navigation destination by label.
Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(navLabel(label));
  await tester.pumpAndSettle();
}

/// The widget currently visible (not offstage) matching [finder].
Finder onstage(Finder finder) => finder.hitTestable();

extension ScrollUntil on WidgetTester {
  Future<void> scrollTo(Finder target, {Finder? scrollable}) async {
    await scrollUntilVisible(
      target,
      300,
      scrollable:
          scrollable ??
          find
              .descendant(
                of: find.byType(CustomScrollView).hitTestable().first,
                matching: find.byType(Scrollable),
              )
              .first,
    );
    await pumpAndSettle();
  }
}
