import 'package:finflow/app/routes/app_routes.dart';
import 'package:finflow/data/repositories/settings_repository_impl.dart';
import 'package:finflow/data/sources/finance_store.dart';
import 'package:finflow/features/shell/app_tab.dart';
import 'package:finflow/features/shell/glass_nav_bar.dart';
import 'package:finflow/features/shell/shell_controller.dart';
import 'package:finflow/features/transaction_details/transaction_details_page.dart';
import 'package:finflow/features/transactions/transactions_controller.dart';
import 'package:finflow/shared/widgets/financial_widgets.dart';
import 'package:finflow/shared/widgets/loading.dart';
import 'package:finflow/shared/widgets/selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('boots to the dashboard with sample data clearly labelled', (
    tester,
  ) async {
    await pumpFinFlow(tester);

    expect(find.text('Good evening'), findsOneWidget);
    expect(find.text('NET · OCTOBER'), findsOneWidget);
    expect(find.text('LAST 7 DAYS'), findsOneWidget);
  });

  testWidgets('switches between all five destinations', (tester) async {
    await pumpFinFlow(tester);
    final shell = Get.find<ShellController>();

    await tapTab(tester, 'Activity');
    expect(shell.current.value, AppTab.activity);
    expect(onstage(find.text('Transactions')), findsWidgets);

    await tapTab(tester, 'Cards');
    expect(onstage(find.text('DUE ON STATEMENTS')), findsOneWidget);

    await tapTab(tester, 'Insights');
    expect(onstage(find.text('SPENDING BY CATEGORY')), findsOneWidget);

    await tapTab(tester, 'Profile');
    expect(onstage(find.text('Appearance')), findsOneWidget);

    await tapTab(tester, 'Home');
    expect(onstage(find.text('Good evening')), findsOneWidget);
  });

  testWidgets('tab switch animates in both directions and keeps state', (
    tester,
  ) async {
    await pumpFinFlow(tester);

    // Forward (Home -> Insights): mid-animation both tabs are painted.
    await tester.tap(navLabel('Insights'));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('Good evening'), findsOneWidget);
    expect(find.text('SPENDING BY CATEGORY'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Good evening').hitTestable(), findsNothing);

    // Backward (Insights -> Home).
    await tester.tap(navLabel('Home'));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('SPENDING BY CATEGORY'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(onstage(find.text('Good evening')), findsOneWidget);
  });

  testWidgets('system back on a non-home tab returns to Home first', (
    tester,
  ) async {
    await pumpFinFlow(tester);
    await tapTab(tester, 'Insights');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(Get.find<ShellController>().current.value, AppTab.home);
    expect(onstage(find.text('Good evening')), findsOneWidget);
  });

  testWidgets('opens details with a hero and returns with the reverse '
      'transition (back button and system back)', (tester) async {
    await pumpFinFlow(tester);
    await tapTab(tester, 'Activity');

    final firstTile = onstage(find.byType(TransactionTile)).first;
    final title = tester.widget<TransactionTile>(firstTile).transaction.title;
    await tester.tap(firstTile);

    // Mid forward transition: both routes are on screen and the avatar is
    // flying.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(TransactionDetailsPage), findsOneWidget);
    expect(find.byType(Hero), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('Transaction details'), findsOneWidget);
    expect(find.text(title), findsWidgets);

    // Back via the app bar.
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(TransactionDetailsPage), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(TransactionDetailsPage), findsNothing);
    expect(onstage(find.text('Transactions')), findsWidgets);

    // Again, back via the system back button.
    await tester.tap(onstage(find.byType(TransactionTile)).first);
    await tester.pumpAndSettle();
    expect(find.byType(TransactionDetailsPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(TransactionDetailsPage), findsNothing);
    expect(Get.find<ShellController>().current.value, AppTab.activity);
  });

  testWidgets('home recent activity opens details', (tester) async {
    await pumpFinFlow(tester);
    await tester.scrollTo(find.text('RECENT ACTIVITY'));
    await tester.tap(onstage(find.byType(TransactionTile)).first);
    await tester.pumpAndSettle();
    expect(find.text('Transaction details'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
  });

  testWidgets('deep link to details without arguments loads by id', (
    tester,
  ) async {
    await pumpFinFlow(tester);
    Get.toNamed<void>(AppRoutes.transaction('sample-0001'));
    await tester.pumpAndSettle();
    expect(find.text('Transaction details'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
  });

  testWidgets('unknown transaction id shows an error state', (tester) async {
    await pumpFinFlow(tester);
    Get.toNamed<void>(AppRoutes.transaction('missing'));
    await tester.pumpAndSettle();
    expect(find.text('This transaction is no longer available.'), findsOne);
  });

  testWidgets('unknown route shows not-found page', (tester) async {
    await pumpFinFlow(tester);
    Get.toNamed<void>('/does/not/exist');
    await tester.pumpAndSettle();
    expect(find.text('Page not found'), findsOneWidget);
  });

  testWidgets('changing a category updates details and history', (
    tester,
  ) async {
    await pumpFinFlow(tester);
    await tapTab(tester, 'Activity');

    // Pick a spending transaction that is not already Travel.
    final tile = onstage(find.byType(TransactionTile)).evaluate().firstWhere((
      e,
    ) {
      final t = (e.widget as TransactionTile).transaction;
      return t.isDebit && t.category.label != 'Travel';
    });
    final id = (tile.widget as TransactionTile).transaction.id;
    await tester.tap(find.byWidget(tile.widget));
    await tester.pumpAndSettle();

    // The button sits below the fold on the details page.
    await tester.scrollUntilVisible(
      find.text('Change category'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change category'));
    await tester.pumpAndSettle();
    expect(find.text('Change category'), findsNWidgets(2)); // button + sheet
    await tester.tap(find.widgetWithText(ChoiceRow, 'Travel'));
    await tester.pumpAndSettle();

    expect(find.text('Category updated'), findsOneWidget);
    expect(find.widgetWithText(Row, 'Travel'), findsWidgets);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    final updated = tester
        .widgetList<TransactionTile>(find.byType(TransactionTile))
        .firstWhere((w) => w.transaction.id == id);
    expect(updated.transaction.category.label, 'Travel');
  });

  testWidgets('direction chips and debounced search filter the history', (
    tester,
  ) async {
    await pumpFinFlow(tester);
    await tapTab(tester, 'Activity');
    final controller = Get.find<TransactionsController>();

    await tester.tap(find.text('Income').hitTestable());
    await tester.pumpAndSettle();
    final tiles = tester.widgetList<TransactionTile>(
      find.byType(TransactionTile),
    );
    expect(tiles, isNotEmpty);
    expect(tiles.every((t) => t.transaction.isCredit), isTrue);

    await tester.tap(find.text('All').hitTestable());
    await tester.enterText(find.byType(TextField), 'brew');
    // Not applied until the debounce elapses.
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.filter.value.query, isEmpty);
    await tester.pump(TransactionsController.searchDebounce);
    await tester.pumpAndSettle();
    expect(controller.filter.value.query, 'brew');
    final matches = tester.widgetList<TransactionTile>(
      find.byType(TransactionTile),
    );
    expect(matches, isNotEmpty);
    expect(matches.every((t) => t.transaction.title.contains('Brew')), isTrue);

    await tester.enterText(find.byType(TextField), 'zzzz-no-match');
    await tester.pump(TransactionsController.searchDebounce);
    await tester.pumpAndSettle();
    expect(find.text('No matches'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionTile), findsWidgets);
  });

  testWidgets('filter sheet applies sort and shows an active badge', (
    tester,
  ) async {
    await pumpFinFlow(tester);
    await tapTab(tester, 'Activity');

    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
    expect(find.text('Filter & sort'), findsOneWidget);
    await tester.tap(find.widgetWithText(OptionTile, 'Highest amount'));
    await tester.pump();
    // The confirm button previews the result count.
    expect(find.textContaining(RegExp(r'^Show \d+ results$')), findsOneWidget);
    await tester.tap(find.textContaining('results'));
    await tester.pumpAndSettle();

    expect(find.text('Filter & sort'), findsNothing);
    expect(find.byTooltip('Filters (1 active)'), findsOneWidget);
    final amounts = tester
        .widgetList<TransactionTile>(find.byType(TransactionTile))
        .map((t) => t.transaction.amount.minor)
        .toList();
    expect(amounts, [...amounts]..sort((a, b) => b.compareTo(a)));

    // Dismissing without applying keeps the previous filter.
    await tester.tap(find.byTooltip('Filters (1 active)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OptionTile, 'Oldest first'));
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Filters (1 active)'), findsOneWidget);
    expect(
      Get.find<TransactionsController>().filter.value.sort.label,
      'Highest amount',
    );
  });

  testWidgets('theme switch applies immediately and persists', (tester) async {
    final store = await pumpFinFlow(tester);
    await tapTab(tester, 'Profile');

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Appearance'));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(store.getString(SettingsRepositoryImpl.themeKey), 'dark');

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Appearance'))).brightness,
      Brightness.light,
    );
  });

  testWidgets('stored theme preference is used on launch', (tester) async {
    await pumpFinFlow(tester, prefs: {SettingsRepositoryImpl.themeKey: 'dark'});
    expect(
      Theme.of(tester.element(find.text('Good evening'))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('first run with no data shows inviting empty states', (
    tester,
  ) async {
    await pumpFinFlow(tester, financeStore: InMemoryFinanceStore());

    expect(find.text('Start with your first transaction'), findsOneWidget);

    await tapTab(tester, 'Activity');
    expect(onstage(find.text('No transactions yet')), findsOneWidget);
    await tapTab(tester, 'Cards');
    expect(onstage(find.text('Track your credit cards')), findsOneWidget);
    await tapTab(tester, 'Insights');
    expect(onstage(find.text('No insights yet')), findsOneWidget);
    await tapTab(tester, 'Profile');
    expect(find.text('Stored on this device'), findsOneWidget);
  });

  testWidgets('shows loading skeletons until data arrives', (tester) async {
    await pumpFinFlow(tester, settle: false);
    // First frame: controllers are loading.
    expect(find.byType(Shimmer), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('NET · OCTOBER'), findsOneWidget);
  });

  testWidgets('profile has no developer tools', (tester) async {
    await pumpFinFlow(tester);
    await tapTab(tester, 'Profile');
    await tester.scrollTo(find.text('Open-source licences'));
    expect(find.text('Developer'), findsNothing);
    expect(find.text('Component gallery'), findsNothing);
    expect(find.textContaining('sample', findRichText: true), findsNothing);
    expect(find.textContaining('Sample'), findsNothing);
  });

  testWidgets('first launch shows onboarding, then remembers it', (
    tester,
  ) async {
    final store = await pumpFinFlow(
      tester,
      prefs: {SettingsRepositoryImpl.onboardingKey: 'pending'},
    );
    expect(find.textContaining('Every rupee'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Know where'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('only yours'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.byType(GlassNavBar), findsOneWidget);
    expect(store.getString(SettingsRepositoryImpl.onboardingKey), 'done');
  });

  testWidgets('skip goes straight to the app', (tester) async {
    await pumpFinFlow(
      tester,
      prefs: {SettingsRepositoryImpl.onboardingKey: 'pending'},
    );
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(onstage(find.text('Good evening')), findsOneWidget);
  });
}
