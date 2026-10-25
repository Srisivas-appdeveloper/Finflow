import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/utils/clock.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/card_bill.dart';
import '../../domain/entities/credit_card.dart';
import '../../domain/entities/emi_plan.dart';
import '../../domain/entities/money.dart';
import '../../domain/repositories/card_repository.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import 'card_sheets.dart';

/// User flows for cards, bills and EMIs: open the right sheet, save through
/// [CardRepository], and confirm with a short message. Shared by the Cards
/// tab and the card details page.
class CardActions {
  CardActions({CardRepository? repository, AppClock? clock})
    : _repo = repository ?? Get.find<CardRepository>(),
      _clock = clock ?? Get.find<AppClock>();

  final CardRepository _repo;
  final AppClock _clock;

  DateTime get _now => _clock.now();

  void _snack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<T?> _guard<T>(BuildContext context, Future<T> Function() run) async {
    try {
      return await run();
    } on DuplicateBillException {
      _snack(context, 'A bill for that statement date already exists');
    } on ArgumentError catch (e) {
      _snack(context, e.message?.toString() ?? 'Please check the details');
    } catch (_) {
      _snack(context, 'Couldn\'t save. Please try again.');
    }
    return null;
  }

  Future<CreditCard?> addCard(BuildContext context) async {
    final draft = await showFormSheet<CreditCard>(
      context,
      const CardFormSheet(),
    );
    if (draft == null || !context.mounted) return null;
    final saved = await _guard(context, () => _repo.saveCard(draft));
    if (saved != null && context.mounted) _snack(context, 'Card added');
    return saved;
  }

  Future<void> editCard(BuildContext context, CreditCard card) async {
    final draft = await showFormSheet<CreditCard>(
      context,
      CardFormSheet(initial: card),
    );
    if (draft == null || !context.mounted) return;
    await _guard(context, () => _repo.saveCard(draft));
  }

  /// Returns true if the card was deleted.
  Future<bool> deleteCard(BuildContext context, CreditCard card) async {
    final ok = await AppBottomSheet.confirm(
      context,
      title: 'Delete ${card.name}?',
      message:
          'Its bills and EMI plans are deleted too. Payments you recorded '
          'stay in your activity history.',
      confirmLabel: 'Delete card',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !context.mounted) return false;
    final done = await _guard(context, () async {
      await _repo.deleteCard(card.id);
      return true;
    });
    return done ?? false;
  }

  Future<void> updateOutstanding(BuildContext context, CreditCard card) async {
    final amount = await showFormSheet<Money>(
      context,
      OutstandingSheet(card: card),
    );
    if (amount == null || !context.mounted) return;
    await _guard(
      context,
      () => _repo.saveCard(
        card.copyWith(currentOutstanding: amount, outstandingUpdatedAt: _now),
      ),
    );
  }

  /// Statement dates already used on [card], except [exceptBillId].
  Future<Set<DateTime>> _takenDates(
    String cardId, {
    String? exceptBillId,
  }) async {
    return {
      for (final b in await _repo.bills(cardId: cardId))
        if (b.id != exceptBillId)
          DateTime(
            b.statementDate.year,
            b.statementDate.month,
            b.statementDate.day,
          ),
    };
  }

  Future<void> addBill(BuildContext context, CreditCard card) async {
    final taken = await _takenDates(card.id);
    if (!context.mounted) return;
    final draft = await showFormSheet<CardBill>(
      context,
      BillFormSheet(card: card, now: _now, takenStatementDates: taken),
    );
    if (draft == null || !context.mounted) return;
    final saved = await _guard(context, () => _repo.saveBill(draft));
    if (saved != null && context.mounted) _snack(context, 'Bill added');
  }

  /// Actions available on a bill: pay, edit, delete.
  Future<void> openBill(
    BuildContext context,
    CardBill bill,
    CreditCard card,
  ) async {
    final f = Get.find<Formatters>();
    final choice = await AppBottomSheet.actions<String>(
      context,
      title: '${card.name} bill',
      subtitle:
          '${f.money(bill.totalDue)} · due ${f.fullDate(bill.dueDate)}'
          '${bill.paid.isPositive ? ' · ${f.money(bill.paid)} paid' : ''}',
      icon: Icons.receipt_long_rounded,
      actions: [
        if (!bill.isSettled)
          const SheetAction(
            value: 'pay',
            label: 'Record a payment',
            icon: Icons.credit_score_rounded,
          ),
        const SheetAction(
          value: 'edit',
          label: 'Edit bill',
          icon: Icons.edit_outlined,
        ),
        const SheetAction(
          value: 'delete',
          label: 'Delete bill',
          icon: Icons.delete_outline_rounded,
          destructive: true,
        ),
      ],
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'pay':
        await recordPayment(context, bill);
      case 'edit':
        final taken = await _takenDates(card.id, exceptBillId: bill.id);
        if (!context.mounted) return;
        final draft = await showFormSheet<CardBill>(
          context,
          BillFormSheet(
            card: card,
            now: _now,
            initial: bill,
            takenStatementDates: taken,
          ),
        );
        if (draft != null && context.mounted) {
          await _guard(context, () => _repo.saveBill(draft));
        }
      case 'delete':
        final ok = await AppBottomSheet.confirm(
          context,
          title: 'Delete this bill?',
          message: 'Payments you recorded stay in your activity history.',
          confirmLabel: 'Delete bill',
          destructive: true,
          icon: Icons.delete_outline_rounded,
        );
        if (ok && context.mounted) {
          await _guard(context, () => _repo.deleteBill(bill.id));
        }
    }
  }

  Future<void> recordPayment(BuildContext context, CardBill bill) async {
    final draft = await showFormSheet<PaymentDraft>(
      context,
      PaymentSheet(bill: bill, now: _now),
    );
    if (draft == null || !context.mounted) return;
    final saved = await _guard(
      context,
      () => _repo.recordPayment(
        billId: bill.id,
        amount: draft.amount,
        paidOn: draft.paidOn,
        method: draft.method,
      ),
    );
    if (saved != null && context.mounted) _snack(context, 'Payment recorded');
  }

  Future<void> addEmi(BuildContext context, CreditCard card) async {
    final draft = await showFormSheet<EmiPlan>(
      context,
      EmiFormSheet(card: card, now: _now),
    );
    if (draft == null || !context.mounted) return;
    final saved = await _guard(context, () => _repo.saveEmi(draft));
    if (saved != null && context.mounted) _snack(context, 'EMI added');
  }

  /// Actions on an EMI: edit, close early (or reopen), delete.
  Future<void> openEmi(
    BuildContext context,
    EmiPlan plan,
    CreditCard card,
  ) async {
    final choice = await AppBottomSheet.actions<String>(
      context,
      title: plan.title,
      icon: Icons.calendar_month_rounded,
      actions: [
        const SheetAction(
          value: 'edit',
          label: 'Edit EMI',
          icon: Icons.edit_outlined,
        ),
        plan.isClosed
            ? const SheetAction(
                value: 'reopen',
                label: 'Reopen',
                icon: Icons.restart_alt_rounded,
              )
            : const SheetAction(
                value: 'close',
                label: 'Mark as closed early',
                icon: Icons.task_alt_rounded,
              ),
        const SheetAction(
          value: 'delete',
          label: 'Delete EMI',
          icon: Icons.delete_outline_rounded,
          destructive: true,
        ),
      ],
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'edit':
        final draft = await showFormSheet<EmiPlan>(
          context,
          EmiFormSheet(card: card, now: _now, initial: plan),
        );
        if (draft != null && context.mounted) {
          await _guard(context, () => _repo.saveEmi(draft));
        }
      case 'close':
        await _guard(
          context,
          () => _repo.saveEmi(plan.copyWith(closedOn: _now)),
        );
      case 'reopen':
        await _guard(context, () => _repo.saveEmi(plan.copyWith(reopen: true)));
      case 'delete':
        final ok = await AppBottomSheet.confirm(
          context,
          title: 'Delete this EMI?',
          message: 'Only the instalment schedule is removed.',
          confirmLabel: 'Delete EMI',
          destructive: true,
          icon: Icons.delete_outline_rounded,
        );
        if (ok && context.mounted) {
          await _guard(context, () => _repo.deleteEmi(plan.id));
        }
    }
  }
}
