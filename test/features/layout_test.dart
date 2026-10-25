import 'package:finflow/data/repositories/settings_repository_impl.dart';
import 'package:finflow/features/transaction_details/transaction_details_page.dart';
import 'package:finflow/shared/widgets/financial_widgets.dart';
import 'package:finflow/features/shell/glass_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

/// Renders every primary screen across phone, landscape and tablet sizes,
/// both themes and enlarged text. Any RenderFlex overflow or layout
/// exception fails the test.
void main() {
  const sizes = {
    'small phone 320x640': Size(320, 640),
    'phone 360x780': Size(360, 780),
    'large phone 412x915': Size(412, 915),
    'phone landscape 780x360': Size(780, 360),
    'tablet portrait 800x1280': Size(800, 1280),
    'tablet landscape 1280x800': Size(1280, 800),
  };
  const tabs = ['Home', 'Activity', 'Cards', 'Insights', 'Profile'];

  Future<void> goTo(WidgetTester tester, String label) async {
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

  for (final MapEntry(key: name, value: size) in sizes.entries) {
    for (final theme in ['light', 'dark']) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('$name · $theme · text ${scale}x', (tester) async {
          await pumpFinFlow(
            tester,
            size: size,
            textScale: scale,
            prefs: {SettingsRepositoryImpl.themeKey: theme},
          );

          final compact = size.width < 600;
          expect(
            find.byType(compact ? GlassNavBar : NavigationRail),
            findsOneWidget,
          );

          for (final tab in tabs) {
            await goTo(tester, tab);
            // Scroll through the page so lazily built content lays out too.
            final scrollable = find
                .descendant(
                  of: find.byType(CustomScrollView).hitTestable().first,
                  matching: find.byType(Scrollable),
                )
                .first;
            await tester.fling(scrollable, const Offset(0, -2000), 3000);
            await tester.pumpAndSettle();
            await tester.fling(scrollable, const Offset(0, 2000), 3000);
            await tester.pumpAndSettle();
          }

          await goTo(tester, 'Activity');
          await tester.tap(onstage(find.byType(TransactionTile)).first);
          await tester.pumpAndSettle();
          expect(find.byType(TransactionDetailsPage), findsOneWidget);
          await tester.fling(
            find.byType(ListView).last,
            const Offset(0, -2000),
            3000,
          );
          await tester.pumpAndSettle();
        });
      }
    }
  }

  for (final MapEntry(key: name, value: size) in sizes.entries) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('onboarding · $name · text ${scale}x', (tester) async {
        await pumpFinFlow(
          tester,
          size: size,
          textScale: scale,
          prefs: {SettingsRepositoryImpl.onboardingKey: 'pending'},
        );
        for (var page = 0; page < 2; page++) {
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
        }
        expect(find.text('Get started'), findsOneWidget);
      });
    }
  }
}
