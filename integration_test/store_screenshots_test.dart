import 'package:finflow/app/bindings/app_binding.dart';
import 'package:finflow/app/finflow_app.dart';
import 'package:finflow/app/routes/app_routes.dart';
import 'package:finflow/core/config/app_environment.dart';
import 'package:finflow/core/utils/clock.dart';
import 'package:finflow/data/repositories/settings_repository_impl.dart';
import 'package:finflow/data/sources/finance_store.dart';
import 'package:finflow/data/sources/key_value_store.dart';
import 'package:finflow/domain/entities/money.dart';
import 'package:finflow/domain/entities/split.dart';
import 'package:finflow/domain/entities/transaction.dart';
import 'package:finflow/domain/entities/transaction_category.dart';
import 'package:finflow/domain/repositories/split_repository.dart';
import 'package:finflow/domain/services/split_ledger.dart';
import 'package:finflow/features/shell/glass_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

import '../test/fixtures/sample_data.dart';

/// Captures the Play Store phone screenshots from fictional test data.
/// Run on an emulator set to a 9:16 screen (Play allows at most 2:1):
///
///   adb -s EMULATOR_ID shell wm size 1080x1920
///   flutter drive -d EMULATOR_ID --driver=test_driver/screenshot_driver.dart \
///     --target=integration_test/store_screenshots_test.dart
///   adb -s EMULATOR_ID shell wm size reset
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 24, 18, 30);

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    // Let entrance animations and rolling numbers finish.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  Future<void> tab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(of: find.byType(GlassNavBar), matching: find.text(label)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('store screenshots', (tester) async {
    final bundle = const SampleDataGenerator().generate(now);
    Get.reset();
    AppBinding(
      environment: const AppEnvironment(launchIntro: false),
      preferences: InMemoryStore({
        SettingsRepositoryImpl.onboardingKey: 'done',
        SettingsRepositoryImpl.themeKey: 'light',
      }),
      financeStore: InMemoryFinanceStore(
        transactions: [...bundle.transactions, _freelance(now)],
        cards: bundle.cards,
        bills: bundle.bills,
        emis: bundle.emis,
      ),
      clock: AppClock(() => now),
    ).dependencies();
    final room = await _seedSplit(now);

    await tester.pumpWidget(const FinFlowApp());
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();

    await shot(tester, '01-home');

    Get.toNamed<void>(AppRoutes.splitGroupOf(room.id));
    await shot(tester, '02-split-group');
    Get.back<void>();
    await tester.pumpAndSettle();

    Get.toNamed<void>(AppRoutes.splitExpenseOf(room.id));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Total amount'),
      '2400',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'What was it for?'),
      'Groceries for the week',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -420));
    await shot(tester, '03-split-expense');
    Get.back<void>();
    await tester.pumpAndSettle();

    await tab(tester, 'Activity');
    await shot(tester, '04-activity');

    await tab(tester, 'Insights');
    await shot(tester, '05-insights');

    await tab(tester, 'Cards');
    await shot(tester, '06-cards');

    Get.toNamed<void>(AppRoutes.card(bundle.cards.first.id));
    await shot(tester, '07-card-details');
    Get.back<void>();
    await tester.pumpAndSettle();

    await tab(tester, 'Profile');
    await tester.tap(find.text('Dark'));
    await tab(tester, 'Home');
    await shot(tester, '08-home-dark');
  });
}

/// Extra income so the example month ends with money left over.
Transaction _freelance(DateTime now) => Transaction(
  id: 'store-freelance',
  title: 'Freelance design project',
  amount: const Money(2500000),
  direction: TransactionDirection.credit,
  category: TransactionCategory.salary,
  status: TransactionStatus.completed,
  occurredAt: now.subtract(const Duration(days: 6, hours: 2)),
  paymentMethod: PaymentMethod.bankTransfer,
);

/// A hostel room with a few shared costs and one repayment.
Future<SplitGroup> _seedSplit(DateTime now) async {
  final repo = Get.find<SplitRepository>();
  final g = await repo.saveGroup(
    SplitGroup(
      id: '',
      name: 'Hostel room 204',
      members: const [
        SplitMember(id: '', name: 'Arjun'),
        SplitMember(id: '', name: 'Meera'),
        SplitMember(id: '', name: 'Karthik'),
      ],
      createdAt: now.subtract(const Duration(days: 30)),
    ),
  );
  final [you, arjun, meera, karthik] = g.everyoneIds;

  Future<void> expense(
    String title,
    int rupees,
    TransactionCategory category,
    String paidBy,
    int daysAgo,
  ) => repo.saveExpense(
    SplitExpense(
      id: '',
      groupId: g.id,
      title: title,
      amount: Money(rupees * 100),
      category: category,
      paidBy: paidBy,
      mode: SplitMode.equal,
      shares: [
        for (final e in SplitCalculator.equal(Money(rupees * 100), [
          you,
          arjun,
          meera,
          karthik,
        ]).entries)
          SplitShare(memberId: e.key, amount: e.value),
      ],
      occurredAt: now.subtract(Duration(days: daysAgo, hours: 3)),
    ),
    method: PaymentMethod.upi,
  );

  await expense('Room rent', 24000, TransactionCategory.bills, arjun, 20);
  await expense('Electricity', 1860, TransactionCategory.bills, you, 9);
  await expense('Weekend biryani', 1440, TransactionCategory.dining, you, 2);
  await expense('Wi-Fi recharge', 999, TransactionCategory.bills, meera, 5);
  await repo.saveSettlement(
    SplitSettlement(
      id: '',
      groupId: g.id,
      fromId: you,
      toId: arjun,
      amount: const Money(400000),
      occurredAt: now.subtract(const Duration(days: 12)),
    ),
  );
  return g;
}
