import 'package:finflow/data/sources/finance_store.dart';
import 'package:finflow/domain/entities/card_bill.dart';
import 'package:finflow/domain/entities/transaction_category.dart';
import 'package:finflow/domain/repositories/card_repository.dart';
import 'package:finflow/domain/repositories/transaction_repository.dart';
import 'package:finflow/features/cards/widgets/card_widgets.dart';
import 'package:finflow/features/transaction_details/transaction_details_page.dart';
import 'package:finflow/shared/widgets/app_button.dart';
import 'package:finflow/shared/widgets/financial_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../helpers/test_app.dart';

Finder button(String label) => find.widgetWithText(AppButton, label).last;

Future<void> enter(WidgetTester tester, String label, String text) async {
  await tester.enterText(find.widgetWithText(TextFormField, label).last, text);
  await tester.pump();
}

void main() {
  testWidgets('add, edit and delete a transaction', (tester) async {
    await pumpFinFlow(tester, financeStore: InMemoryFinanceStore());

    await tester.tap(button('Add transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Paid to'), findsOneWidget);

    // Validation.
    await tester.tap(button('Add transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount greater than zero'), findsOneWidget);
    expect(find.text('Who did you pay?'), findsOneWidget);

    await enter(tester, 'Amount', '250.5');
    await enter(tester, 'Paid to', 'Corner store');
    await tester.tap(button('Add transaction'));
    await tester.pumpAndSettle();

    final repo = Get.find<TransactionRepository>();
    final stored = (await repo.getAll()).single;
    expect(stored.title, 'Corner store');
    expect(stored.amount.minor, 25050);
    // The dashboard replaces the empty state.
    expect(find.text('Start with your first transaction'), findsNothing);

    // Open, edit.
    await tapTab(tester, 'Activity');
    await tester.tap(find.byType(TransactionTile).hitTestable().first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit transaction'), findsOneWidget);
    await enter(tester, 'Paid to', 'Market');
    await tester.tap(button('Save changes'));
    await tester.pumpAndSettle();
    expect((await repo.getAll()).single.title, 'Market');
    expect(find.text('Market'), findsWidgets);

    // Delete with confirmation.
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(button('Delete'));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionDetailsPage), findsNothing);
    expect(await repo.getAll(), isEmpty);
  });

  testWidgets('income switches categories', (tester) async {
    await pumpFinFlow(tester, financeStore: InMemoryFinanceStore());
    await tester.tap(button('Add transaction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Income').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Received from'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Groceries'), findsNothing);
    // Bill payments can only be made from a bill.
    expect(find.text('Card bill payment'), findsNothing);
  });

  testWidgets('add a card and a bill, pay it in full', (tester) async {
    final store = InMemoryFinanceStore();
    await pumpFinFlow(tester, financeStore: store);
    await tapTab(tester, 'Cards');
    expect(onstage(find.text('Track your credit cards')), findsOneWidget);

    await tester.tap(button('Add a credit card'));
    await tester.pumpAndSettle();
    await enter(tester, 'Card name', 'Travel card');
    await enter(tester, 'Credit limit', '100000');
    await tester.tap(button('Add card'));
    await tester.pumpAndSettle();
    expect(onstage(find.text('DUE ON STATEMENTS')), findsOneWidget);
    expect(find.text('Travel card'), findsWidgets);

    // Open the card and add a bill.
    await tester.tap(find.text('Travel card').hitTestable().first);
    await tester.pumpAndSettle();
    await tester.tap(button('Add bill'));
    await tester.pumpAndSettle();
    await enter(tester, 'Total amount due', '5000');
    await enter(tester, 'Minimum amount due (optional)', '250');
    await tester.tap(button('Add bill'));
    await tester.pumpAndSettle();

    final cards = Get.find<CardRepository>();
    var bill = (await cards.bills()).single;
    expect(bill.totalDue.minor, 500000);
    expect(bill.status, BillStatus.unpaid);

    // Pay it from the bill's actions.
    await tester.tap(find.byType(BillTile).hitTestable().first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record a payment'));
    await tester.pumpAndSettle();
    await tester.tap(button('Record payment'));
    await tester.pumpAndSettle();

    bill = (await cards.bills()).single;
    expect(bill.status, BillStatus.paid);
    final payment = (await store.transactions()).single;
    expect(payment.category, TransactionCategory.cardPayment);
    expect(payment.billId, bill.id);
  });

  testWidgets('a duplicate statement is refused with a message', (
    tester,
  ) async {
    await pumpFinFlow(tester, financeStore: InMemoryFinanceStore());
    await tapTab(tester, 'Cards');
    await tester.tap(button('Add a credit card'));
    await tester.pumpAndSettle();
    await enter(tester, 'Card name', 'Card');
    await enter(tester, 'Credit limit', '1000');
    await tester.tap(button('Add card'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Card').hitTestable().first);
    await tester.pumpAndSettle();

    for (var i = 0; i < 2; i++) {
      await tester.tap(button('Add bill'));
      await tester.pumpAndSettle();
      await enter(tester, 'Total amount due', '100');
      await tester.tap(button('Add bill'));
      await tester.pumpAndSettle();
    }
    // The sheet stays open with an inline error; nothing is lost.
    expect(
      find.text('You already added the bill for this statement date'),
      findsOneWidget,
    );
    expect(await Get.find<CardRepository>().bills(), hasLength(1));
  });

  testWidgets('a bill payment keeps its type and category', (tester) async {
    await pumpFinFlow(tester);
    // The fixture contains a recorded payment for a settled bill.
    final payment = (await Get.find<TransactionRepository>().getAll())
        .firstWhere((t) => t.billId != null);
    await tapTab(tester, 'Activity');
    await tester.enterText(find.byType(TextField).first, payment.title);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TransactionTile).hitTestable().first);
    await tester.pumpAndSettle();

    // No category change on the details page.
    expect(find.text('Change category'), findsNothing);

    // The edit form offers no Spending/Income switch and only this category.
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Income'), findsNothing);
    expect(find.text('Card bill payment'), findsOneWidget);
    expect(find.text('Groceries'), findsNothing);
  });

  testWidgets('screens stay live after replaying the welcome tour', (
    tester,
  ) async {
    await pumpFinFlow(tester);
    await tapTab(tester, 'Profile');
    await tester.scrollTo(find.text('Show welcome tour'));
    await tester.tap(find.text('Show welcome tour'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // Back in the app (not a rebuilt one): delete from Activity and the
    // list must refresh.
    await tapTab(tester, 'Activity');
    final tile = find.byType(TransactionTile).hitTestable().first;
    final id = tester.widget<TransactionTile>(tile).transaction.id;
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(button('Delete'));
    await tester.pumpAndSettle();
    final shown = tester
        .widgetList<TransactionTile>(find.byType(TransactionTile))
        .map((t) => t.transaction.id);
    expect(shown, isNot(contains(id)));
  });
}
