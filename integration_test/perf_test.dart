import 'package:finflow/app/bindings/app_binding.dart';
import 'package:finflow/app/finflow_app.dart';
import 'package:finflow/core/config/app_environment.dart';
import 'package:finflow/data/sources/finance_store.dart';
import 'package:finflow/data/sources/key_value_store.dart';
import 'package:finflow/features/shell/glass_nav_bar.dart';
import 'package:finflow/shared/widgets/financial_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

import '../test/fixtures/sample_data.dart';

/// Records frame timings while switching tabs and opening transactions,
/// with all real animations running. Run on the emulator with:
///   flutter drive --profile -d emulator-5554 \
///     --driver=test_driver/perf_driver.dart \
///     --target=integration_test/perf_test.dart
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  Future<void> tab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(of: find.byType(GlassNavBar), matching: find.text(label)),
    );
    await wait(1100);
  }

  testWidgets('tab switching and opening details', (tester) async {
    Get.reset();
    AppBinding(
      environment: const AppEnvironment(),
      preferences: InMemoryStore({'settings.onboarding': 'done'}),
      financeStore: _sampleStore(),
    ).dependencies();
    await tester.pumpWidget(const FinFlowApp());
    await wait(5000); // intro, loading and entrance animations

    await binding.watchPerformance(() async {
      for (var round = 0; round < 2; round++) {
        await tab(tester, 'Activity');
        await tab(tester, 'Insights');
        await tab(tester, 'Profile');
        await tab(tester, 'Home');
      }
      await tab(tester, 'Activity');
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byType(TransactionTile).hitTestable().first);
        await wait(1300);
        await tester.tap(find.byType(BackButton));
        await wait(1100);
      }
    }, reportKey: 'performance');
  });
}

InMemoryFinanceStore _sampleStore() {
  final bundle = const SampleDataGenerator().generate(DateTime.now());
  return InMemoryFinanceStore(
    transactions: bundle.transactions,
    cards: bundle.cards,
    bills: bundle.bills,
    emis: bundle.emis,
  );
}
