import 'package:finflow/app/routes/app_routes.dart';
import 'package:finflow/data/repositories/settings_repository_impl.dart';
import 'package:finflow/domain/entities/money.dart';
import 'package:finflow/domain/entities/split.dart';
import 'package:finflow/domain/entities/transaction_category.dart';
import 'package:finflow/domain/repositories/split_repository.dart';
import 'package:finflow/features/split/split_expense_form_page.dart';
import 'package:finflow/features/split/split_group_page.dart';
import 'package:finflow/features/split/split_page.dart';
import 'package:finflow/shared/widgets/selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../helpers/test_app.dart';

/// Split screens, sheets and the expense form at every size, both themes
/// and enlarged text, with long names and large amounts. Any overflow
/// fails the test.
void main() {
  const sizes = {
    'small phone 320x640': Size(320, 640),
    'phone 360x780': Size(360, 780),
    'phone landscape 780x360': Size(780, 360),
    'tablet portrait 800x1280': Size(800, 1280),
  };

  Future<SplitGroup> seed() async {
    final repo = Get.find<SplitRepository>();
    final g = await repo.saveGroup(
      SplitGroup(
        id: '',
        name: 'Hostel block C, room 204 and the kitchen crew',
        members: const [
          SplitMember(id: '', name: 'Arunachalam Venkataraman'),
          SplitMember(id: '', name: 'Bala'),
          SplitMember(id: '', name: 'Chitra Lakshmi Narayanan'),
        ],
        createdAt: testNow,
      ),
    );
    final ids = g.everyoneIds;
    await repo.saveExpense(
      SplitExpense(
        id: '',
        groupId: g.id,
        title: 'Monthly rent including maintenance and water charges',
        amount: const Money(4800000000),
        category: TransactionCategory.bills,
        paidBy: ids[1],
        mode: SplitMode.equal,
        shares: [
          for (final id in ids)
            SplitShare(memberId: id, amount: const Money(1200000000)),
        ],
        occurredAt: testNow,
      ),
    );
    await repo.saveSettlement(
      SplitSettlement(
        id: '',
        groupId: g.id,
        fromId: ids[3],
        toId: ids[1],
        amount: const Money(50000),
        occurredAt: testNow,
      ),
    );
    return g;
  }

  Future<void> scrollThrough(WidgetTester tester) async {
    final list = find.byType(ListView).hitTestable();
    if (list.evaluate().isEmpty) return;
    await tester.fling(list.last, const Offset(0, -3000), 3000);
    await tester.pumpAndSettle();
    await tester.fling(list.last, const Offset(0, 3000), 3000);
    await tester.pumpAndSettle();
  }

  for (final MapEntry(key: name, value: size) in sizes.entries) {
    for (final theme in ['light', 'dark']) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('split · $name · $theme · text ${scale}x', (tester) async {
          await pumpFinFlow(
            tester,
            size: size,
            textScale: scale,
            prefs: {SettingsRepositoryImpl.themeKey: theme},
          );
          final g = await seed();

          Get.toNamed<void>(AppRoutes.split);
          await tester.pumpAndSettle();
          expect(find.byType(SplitPage), findsOneWidget);
          await scrollThrough(tester);

          Get.toNamed<void>(AppRoutes.splitGroupOf(g.id));
          await tester.pumpAndSettle();
          expect(find.byType(SplitGroupPage), findsOneWidget);
          await scrollThrough(tester);

          // Sheets.
          await tester.tap(find.byTooltip('Group options'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Edit group and people'));
          await tester.pumpAndSettle();
          expect(find.text('Edit group'), findsOneWidget);
          Navigator.of(tester.element(find.text('Edit group'))).pop();
          await tester.pumpAndSettle();

          await tester.tap(find.text('Settle up').last);
          await tester.pumpAndSettle();
          expect(find.text('Record a payment'), findsOneWidget);
          Navigator.of(tester.element(find.text('Record a payment'))).pop();
          await tester.pumpAndSettle();

          // Expense form in every split mode.
          Get.toNamed<void>(AppRoutes.splitExpenseOf(g.id));
          await tester.pumpAndSettle();
          expect(find.byType(SplitExpenseFormPage), findsOneWidget);
          await tester.enterText(
            find.widgetWithText(TextFormField, 'Total amount'),
            '9999999.99',
          );
          await tester.pumpAndSettle();
          for (final mode in ['Equally', 'Amounts', 'Shares']) {
            final segment = find.descendant(
              of: find.byType(GlassSegmented<SplitMode>),
              matching: find.text(mode),
            );
            await tester.scrollUntilVisible(
              segment,
              200,
              scrollable: find
                  .descendant(
                    of: find.byType(ListView).hitTestable().last,
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await Scrollable.ensureVisible(
              tester.element(segment),
              alignment: 0.5,
            );
            await tester.pumpAndSettle();
            await tester.tap(segment, warnIfMissed: false);
            await tester.pumpAndSettle();
            await scrollThrough(tester);
          }
        });
      }
    }
  }
}
