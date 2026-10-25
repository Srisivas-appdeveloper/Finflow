import 'package:finflow/app/bindings/app_binding.dart';
import 'package:finflow/app/finflow_app.dart';
import 'package:finflow/core/config/app_environment.dart';
import 'package:finflow/data/sources/finance_store.dart';
import 'package:finflow/data/sources/key_value_store.dart';
import 'package:finflow/features/transaction_details/transaction_details_page.dart';
import 'package:finflow/shared/widgets/financial_widgets.dart';
import 'package:finflow/features/shell/glass_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

import '../test/fixtures/sample_data.dart';

/// End-to-end walk through every destination and the details flow on a
/// real device or emulator:
///   `flutter test integration_test -d <device-id>`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> tab(WidgetTester tester, String label) async {
    final bar = find.descendant(
      of: find.byType(GlassNavBar),
      matching: find.text(label),
    );
    final rail = find.descendant(
      of: find.byType(NavigationRail),
      matching: find.text(label),
    );
    await tester.tap(bar.evaluate().isNotEmpty ? bar : rail);
    await tester.pumpAndSettle();
  }

  testWidgets('navigates all destinations and details, forward and back', (
    tester,
  ) async {
    Get.reset();
    AppBinding(
      environment: const AppEnvironment(
        launchIntro: false,
        loadingShimmer: false,
      ),
      preferences: InMemoryStore({'settings.onboarding': 'done'}),
      financeStore: _sampleStore(),
    ).dependencies();
    await tester.pumpWidget(const FinFlowApp());
    await tester.pumpAndSettle();

    for (final label in ['Activity', 'Cards', 'Insights', 'Profile']) {
      await tab(tester, label);
    }
    await tab(tester, 'Home');

    await tab(tester, 'Activity');
    await tester.tap(find.byType(TransactionTile).hitTestable().first);
    await tester.pumpAndSettle();
    expect(find.byType(TransactionDetailsPage), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionDetailsPage), findsNothing);

    // Theme switch on device.
    await tab(tester, 'Profile');
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Appearance'))).brightness,
      Brightness.dark,
    );
    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
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
