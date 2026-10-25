import 'package:finflow/domain/entities/card_bill.dart';
import 'package:finflow/domain/entities/credit_card.dart';
import 'package:finflow/domain/entities/emi_plan.dart';
import 'package:finflow/domain/entities/money.dart';
import 'package:finflow/domain/entities/transaction.dart';
import 'package:finflow/domain/entities/transaction_category.dart';
import 'package:finflow/domain/services/bill_reminders.dart';
import 'package:finflow/domain/services/transaction_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

CardBill bill({int total = 1000, int minimum = 100, int paid = 0}) => CardBill(
  id: 'b',
  cardId: 'c',
  statementDate: DateTime(2026, 10, 12),
  dueDate: DateTime(2026, 11, 2),
  totalDue: Money(total),
  minimumDue: Money(minimum),
  paid: Money(paid),
);

void main() {
  group('CardBill', () {
    test('status from payments', () {
      expect(bill().status, BillStatus.unpaid);
      expect(bill(paid: 50).status, BillStatus.partiallyPaid);
      expect(bill(paid: 100).status, BillStatus.minimumPaid);
      expect(bill(paid: 1000).status, BillStatus.paid);
      expect(bill(paid: 1200).remaining.isZero, isTrue);
      expect(bill(total: 0).status, BillStatus.paid);
    });

    test('overdue and days until due', () {
      expect(bill().daysUntilDue(DateTime(2026, 10, 31, 23)), 2);
      expect(bill().isOverdue(DateTime(2026, 11, 2, 23)), isFalse);
      expect(bill().isOverdue(DateTime(2026, 11, 3)), isTrue);
      expect(bill(paid: 1000).isOverdue(DateTime(2026, 12, 1)), isFalse);
      // Minimum paid: not late, though not settled.
      expect(bill(paid: 100).isOverdue(DateTime(2026, 12, 1)), isFalse);
      expect(bill(paid: 99).isOverdue(DateTime(2026, 12, 1)), isTrue);
      // No minimum entered: the full amount is required.
      expect(
        bill(minimum: 0, paid: 500).isOverdue(DateTime(2026, 12, 1)),
        isTrue,
      );
    });
  });

  group('CreditCard', () {
    test('available limit only when outstanding is known, flags stale', () {
      final card = CreditCard(
        id: 'c',
        name: 'Card',
        issuer: '',
        creditLimit: const Money(100000),
        statementDay: 1,
        dueDay: 20,
      );
      expect(card.availableLimit, isNull);
      final known = card.copyWith(
        currentOutstanding: const Money(25000),
        outstandingUpdatedAt: DateTime(2026, 10, 1),
      );
      expect(known.availableLimit, const Money(75000));
      expect(known.utilisation, 0.25);
      expect(known.isOutstandingStale(DateTime(2026, 10, 5)), isFalse);
      expect(known.isOutstandingStale(DateTime(2026, 10, 20)), isTrue);
    });
  });

  group('EmiPlan', () {
    final plan = EmiPlan(
      id: 'e',
      title: 'Laptop',
      principal: const Money(90000),
      instalment: const Money(8000),
      tenureMonths: 12,
      firstDueDate: DateTime(2026, 1, 31),
      processingFee: const Money(500),
    );

    test('schedule clamps to month end', () {
      expect(plan.dueDateOf(0), DateTime(2026, 1, 31));
      expect(plan.dueDateOf(1), DateTime(2026, 2, 28));
      expect(plan.dueDateOf(2), DateTime(2026, 3, 31));
      expect(plan.dueDateOf(11), DateTime(2026, 12, 31));
    });

    test('instalments due, remaining and next due date', () {
      final now = DateTime(2026, 4, 15);
      expect(plan.instalmentsDue(now), 3);
      expect(plan.instalmentsRemaining(now), 9);
      expect(plan.nextDueDate(now), DateTime(2026, 4, 30));
      expect(plan.remainingAmount(now), const Money(72000));
      expect(plan.instalmentsDue(DateTime(2026, 1, 31)), 1);
      expect(plan.isComplete(DateTime(2027, 1, 1)), isTrue);
      expect(plan.nextDueDate(DateTime(2027, 1, 1)), isNull);
    });

    test('cost of credit and early closure', () {
      expect(plan.totalPayable, const Money(96500));
      expect(plan.costOfCredit, const Money(6500));
      final closed = plan.copyWith(closedOn: DateTime(2026, 5, 10));
      expect(closed.instalmentsRemaining(DateTime(2026, 8, 1)), 0);
      expect(closed.nextDueDate(DateTime(2026, 8, 1)), isNull);
      expect(closed.instalmentsDue(DateTime(2026, 8, 1)), 4);
      expect(closed.copyWith(reopen: true).isClosed, isFalse);
    });
  });

  group('No double counting', () {
    test('card bill payments are not spending', () {
      Transaction t(TransactionCategory c, int minor) => Transaction(
        id: '$c',
        title: 'x',
        amount: Money(minor),
        direction: TransactionDirection.debit,
        category: c,
        status: TransactionStatus.completed,
        occurredAt: DateTime(2026, 10, 10),
        paymentMethod: PaymentMethod.card,
      );
      final all = [
        t(TransactionCategory.shopping, 50000),
        t(TransactionCategory.cardPayment, 50000),
      ];
      final m = const TransactionAnalytics().monthSummary(
        all,
        DateTime(2026, 10, 24),
      );
      expect(m.spending.minor, 50000);
    });
  });

  group('BillReminderPlanner', () {
    final cards = {
      'c': CreditCard(
        id: 'c',
        name: 'Travel card',
        issuer: '',
        creditLimit: const Money(1),
        statementDay: 1,
        dueDay: 2,
      ),
    };

    test('three days before and on the due date, at 9am', () {
      final plan = const BillReminderPlanner().plan(
        [bill()],
        cards,
        DateTime(2026, 10, 25),
      );
      expect(plan.map((r) => r.at), [
        DateTime(2026, 10, 30, 9),
        DateTime(2026, 11, 2, 9),
      ]);
      expect(plan.first.title, 'Travel card bill due in 3 days');
      expect(plan.first.body, contains('2 Nov'));
    });

    test('skips paid bills and past times', () {
      expect(
        const BillReminderPlanner().plan(
          [bill(paid: 1000)],
          cards,
          DateTime(2026, 10, 25),
        ),
        isEmpty,
      );
      final late = const BillReminderPlanner().plan(
        [bill()],
        cards,
        DateTime(2026, 11, 1),
      );
      expect(late.map((r) => r.at), [DateTime(2026, 11, 2, 9)]);
    });
  });
}
