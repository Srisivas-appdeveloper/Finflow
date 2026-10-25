import 'package:meta/meta.dart';

import '../entities/card_bill.dart';
import '../entities/credit_card.dart';

@immutable
class PlannedReminder {
  const PlannedReminder({
    required this.at,
    required this.title,
    required this.body,
    required this.billId,
  });

  final DateTime at;
  final String title;
  final String body;
  final String billId;
}

/// Decides when to remind the user about unpaid bills: three days before the
/// due date and on the due date, at [hour] local time. Pure logic, so it is
/// unit-tested independently of the notification plugin.
class BillReminderPlanner {
  const BillReminderPlanner({
    this.daysBefore = 3,
    this.hour = 9,
    this.formatAmount,
  });

  final int daysBefore;
  final int hour;

  /// Formats amounts in reminder text; plain numbers when omitted.
  final String Function(CardBill bill)? formatAmount;

  List<PlannedReminder> plan(
    List<CardBill> bills,
    Map<String, CreditCard> cards,
    DateTime now,
  ) {
    final result = <PlannedReminder>[];
    for (final bill in bills) {
      if (bill.isSettled) continue;
      final card = cards[bill.cardId];
      final name = card?.name ?? 'Credit card';
      final amount =
          formatAmount?.call(bill) ?? bill.remaining.major.toStringAsFixed(2);
      final due = DateTime(
        bill.dueDate.year,
        bill.dueDate.month,
        bill.dueDate.day,
        hour,
      );
      final early = due.subtract(Duration(days: daysBefore));
      if (early.isAfter(now)) {
        result.add(
          PlannedReminder(
            at: early,
            title: '$name bill due in $daysBefore days',
            body: '$amount due on ${_day(bill.dueDate)}.',
            billId: bill.id,
          ),
        );
      }
      if (due.isAfter(now)) {
        result.add(
          PlannedReminder(
            at: due,
            title: '$name bill is due today',
            body: '$amount is due today.',
            billId: bill.id,
          ),
        );
      }
    }
    result.sort((a, b) => a.at.compareTo(b.at));
    return result;
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _day(DateTime d) => '${d.day} ${_months[d.month - 1]}';
}
