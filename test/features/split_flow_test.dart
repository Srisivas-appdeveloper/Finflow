import 'package:finflow/data/sources/finance_store.dart';
import 'package:finflow/domain/entities/split.dart';
import 'package:finflow/domain/entities/transaction.dart';
import 'package:finflow/domain/entities/transaction_category.dart';
import 'package:finflow/domain/repositories/split_repository.dart';
import 'package:finflow/domain/repositories/transaction_repository.dart';
import 'package:finflow/features/split/split_group_page.dart';
import 'package:finflow/features/split/split_page.dart';
import 'package:finflow/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../helpers/test_app.dart';

Finder button(String label) => find.widgetWithText(AppButton, label).last;

Future<void> enter(WidgetTester tester, String label, String text) async {
  await tester.enterText(find.widgetWithText(TextFormField, label).last, text);
  await tester.pump();
}

Future<void> addPerson(WidgetTester tester, String name) async {
  await enter(tester, 'Add a person', name);
  await tester.tap(find.byTooltip('Add person'));
  await tester.pump();
}

/// Scrolls the page's list until [finder] is built and on screen, then
/// taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find
        .descendant(
          of: find.byType(ListView).hitTestable().last,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  // Centre it: the app bar floats over the top of the list.
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('create a group, split an expense and settle up', (tester) async {
    await pumpFinFlow(tester, financeStore: InMemoryFinanceStore());

    // Home offers Split even before any transaction exists.
    await tester.tap(find.text('SPLIT WITH FRIENDS'));
    await tester.pumpAndSettle();
    expect(find.byType(SplitPage), findsOneWidget);
    expect(find.text('Split with roommates'), findsOneWidget);

    await tester.tap(button('Create a group'));
    await tester.pumpAndSettle();
    // Validation.
    await tester.tap(button('Create group'));
    await tester.pumpAndSettle();
    expect(find.text('Give the group a name'), findsOneWidget);
    expect(find.text('Add at least one other person'), findsOneWidget);

    await enter(tester, 'Group name', 'Room 204');
    await addPerson(tester, 'Arun');
    await addPerson(tester, 'arun');
    expect(find.text('arun is already in the group'), findsOneWidget);
    await enter(tester, 'Add a person', 'Bala');
    // Saving adds the name still in the field.
    await tester.tap(button('Create group'));
    await tester.pumpAndSettle();

    expect(find.byType(SplitGroupPage), findsOneWidget);
    expect(find.text('Room 204'), findsWidgets);
    final group = (await Get.find<SplitRepository>().groups()).single;
    expect(group.members.map((m) => m.name), ['Arun', 'Bala']);

    // Add an expense the user paid, split equally.
    await tester.tap(button('Add expense'));
    await tester.pumpAndSettle();
    await tester.tap(button('Save split'));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount greater than zero'), findsOneWidget);
    await enter(tester, 'Total amount', '900');
    await enter(tester, 'What was it for?', 'Rent');
    await tester.pumpAndSettle();
    expect(find.text('Your share is ₹300.00'), findsOneWidget);

    // By shares: you take 2 of 4 (Arun and Bala 1 each).
    await tapVisible(tester, find.text('Shares'));
    await tapVisible(tester, find.byTooltip('More shares for You'));
    expect(find.text('Your share is ₹450.00'), findsOneWidget);

    // By amount starts from the current split and flags a mismatch.
    await tapVisible(tester, find.text('Amounts'));
    expect(find.text('Your share is ₹450.00'), findsOneWidget);
    await enter(tester, 'Bala', '100');
    await tester.pumpAndSettle();
    expect(find.text('₹125.00 left to split'), findsOneWidget);
    await tapVisible(tester, button('Save split'));
    expect(find.text('The amounts must add up to the total'), findsOneWidget);

    await tapVisible(tester, find.text('Shares'));
    expect(find.text('Your share is ₹450.00'), findsOneWidget);
    await tapVisible(tester, button('Save split'));

    expect(find.byType(SplitGroupPage), findsOneWidget);
    expect(find.text('The group owes you'), findsOneWidget);
    final txn = (await Get.find<TransactionRepository>().getAll()).single;
    expect(txn.amount.minor, 90000);
    expect(txn.share!.minor, 45000);

    // Record the first suggested payment.
    await tester.tap(find.widgetWithText(AppButton, 'Record').first);
    await tester.pumpAndSettle();
    expect(find.text('Record a payment'), findsOneWidget);
    await tester.tap(button('Record payment'));
    await tester.pumpAndSettle();
    final settlements = await Get.find<SplitRepository>().settlements();
    expect(settlements.single.toId, SplitMember.youId);
    expect(settlements.single.amount.minor, 22500);

    // Received money is a settlement, not income.
    final all = await Get.find<TransactionRepository>().getAll();
    expect(all, hasLength(2));
    expect(
      all.where((t) => t.isCredit).single.category,
      TransactionCategory.settlement,
    );
  });

  testWidgets('split a new spend from the add form', (tester) async {
    await pumpFinFlow(tester, financeStore: InMemoryFinanceStore());
    await tester.tap(button('Add transaction'));
    await tester.pumpAndSettle();

    await enter(tester, 'Amount', '600');
    await enter(tester, 'Paid to', 'Big Basket');
    await tapVisible(tester, find.byType(Switch));
    await tester.tap(button('Next: split it'));
    await tester.pumpAndSettle();

    // No groups yet, so one is created first.
    expect(find.text('New group'), findsOneWidget);
    await enter(tester, 'Group name', 'Flat');
    await addPerson(tester, 'Chitra');
    await tester.tap(button('Create group'));
    await tester.pumpAndSettle();

    expect(find.text('Split this spend'), findsOneWidget);
    expect(find.text('Your share is ₹300.00'), findsOneWidget);
    await tapVisible(tester, button('Save split'));

    final t = (await Get.find<TransactionRepository>().getAll()).single;
    expect(t.title, 'Big Basket');
    expect(t.amount.minor, 60000);
    expect(t.share!.minor, 30000);
    expect(t.paymentMethod, PaymentMethod.upi);
  });

  testWidgets('date field quick chips', (tester) async {
    await pumpFinFlow(tester, financeStore: InMemoryFinanceStore());
    await tester.tap(button('Add transaction'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Yesterday'));
    expect(find.text('23 Oct 2026'), findsOneWidget);
    await tapVisible(tester, find.text('Today'));
    expect(find.text('24 Oct 2026'), findsOneWidget);

    // The time sheet opens with wheels and closes with the chosen time.
    await tapVisible(tester, find.bySemanticsLabel(RegExp(r'^Time, ')));
    expect(find.text('Set time'), findsOneWidget);
    await tester.tap(button('Set time'));
    await tester.pumpAndSettle();
    expect(find.text('Set time'), findsNothing);

    // The calendar sheet.
    await tapVisible(tester, find.bySemanticsLabel(RegExp(r'^Date, ')));
    expect(find.text('Set date'), findsOneWidget);
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    await tester.tap(button('Set date'));
    await tester.pumpAndSettle();
    expect(find.text('20 Oct 2026'), findsOneWidget);
  });
}
