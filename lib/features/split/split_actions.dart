import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/routes/app_routes.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/split.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/split_repository.dart';
import '../../domain/services/split_ledger.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import 'split_sheets.dart';
import 'widgets/split_widgets.dart';

/// User flows for groups, expenses and settlements: open the right sheet or
/// page, save through [SplitRepository], and confirm with a short message.
class SplitActions {
  SplitActions({SplitRepository? repository, AppClock? clock})
    : _repo = repository ?? Get.find<SplitRepository>(),
      _clock = clock ?? Get.find<AppClock>();

  final SplitRepository _repo;
  final AppClock _clock;

  Formatters get _f => Get.find<Formatters>();

  void _snack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<T?> _guard<T>(BuildContext context, Future<T> Function() run) async {
    try {
      return await run();
    } on MemberInUseException catch (e) {
      _snack(context, '${e.name} has expenses here, so they stay in the group');
    } on ArgumentError catch (e) {
      _snack(context, e.message?.toString() ?? 'Please check the details');
    } catch (_) {
      _snack(context, 'Couldn\'t save. Please try again.');
    }
    return null;
  }

  // --- Groups ---------------------------------------------------------------

  /// Creates a group. Returns it, or null if cancelled.
  Future<SplitGroup?> createGroup(BuildContext context) async {
    final draft = await showSplitSheet<SplitGroup>(
      context,
      GroupFormSheet(now: _clock.now()),
    );
    if (draft == null || !context.mounted) return null;
    // No confirmation message: the new group opens next, and a snack bar
    // would cover its buttons.
    return _guard(context, () => _repo.saveGroup(draft));
  }

  Future<void> editGroup(BuildContext context, SplitGroup group) async {
    final expenses = await _repo.expenses(groupId: group.id);
    final settlements = await _repo.settlements(groupId: group.id);
    if (!context.mounted) return;
    final locked = {
      for (final m in group.members)
        if (expenses.any((e) => e.involves(m.id)) ||
            settlements.any((s) => s.involves(m.id)))
          m.id,
    };
    final draft = await showSplitSheet<SplitGroup>(
      context,
      GroupFormSheet(
        now: _clock.now(),
        initial: group,
        lockedMemberIds: locked,
      ),
    );
    if (draft == null || !context.mounted) return;
    await _guard(context, () => _repo.saveGroup(draft));
  }

  /// Returns true if the group was deleted.
  Future<bool> deleteGroup(BuildContext context, SplitGroup group) async {
    final ok = await AppBottomSheet.confirm(
      context,
      title: 'Delete ${group.name}?',
      message:
          'Its expenses, payments and balances are deleted. Your own '
          'transactions stay in your activity history.',
      confirmLabel: 'Delete group',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !context.mounted) return false;
    final done = await _guard(context, () async {
      await _repo.deleteGroup(group.id);
      return true;
    });
    return done ?? false;
  }

  /// Picks the group to split with: the only one, a choice between several,
  /// or a new one when there are none. Null if cancelled.
  Future<SplitGroup?> pickGroup(BuildContext context) async {
    final groups = await _repo.groups();
    if (!context.mounted) return null;
    if (groups.isEmpty) return createGroup(context);
    if (groups.length == 1) return groups.single;
    // Stand-in option for "create a new group".
    final create = SplitGroup(
      id: '',
      name: 'New group',
      members: const [],
      createdAt: _clock.now(),
    );
    final picked = await AppBottomSheet.choose<SplitGroup>(
      context,
      title: 'Split with',
      subtitle: 'Choose the group that shares this',
      icon: Icons.groups_rounded,
      options: [...groups, create],
      labelOf: (g) => g.name,
      leadingOf: (g) => g.id.isEmpty
          ? const Icon(Icons.add_rounded)
          : const GroupOrb(size: 36),
    );
    if (picked == null || !context.mounted) return null;
    return picked.id.isEmpty ? createGroup(context) : picked;
  }

  /// Splits an existing spend with a group.
  Future<void> splitTransaction(BuildContext context, Transaction t) async {
    final group = await pickGroup(context);
    if (group == null) return;
    await Get.toNamed<void>(
      AppRoutes.splitExpenseOf(group.id, transactionId: t.id),
    );
  }

  Future<void> share(BuildContext context, SplitLedger ledger) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: ledger.summary(_f.money),
          subject: '${ledger.group.name} balances',
        ),
      );
    } catch (_) {
      if (context.mounted) {
        _snack(context, 'Couldn\'t open sharing. Please try again.');
      }
    }
  }

  // --- Expenses -------------------------------------------------------------

  /// Actions on an expense: edit, delete.
  Future<void> openExpense(
    BuildContext context,
    SplitGroup group,
    SplitExpense expense,
  ) async {
    final choice = await AppBottomSheet.actions<String>(
      context,
      title: expense.title,
      subtitle:
          '${_f.money(expense.amount)} · paid by '
          '${expense.paidByYou ? 'you' : group.nameOf(expense.paidBy)} · '
          '${_f.fullDate(expense.occurredAt)}',
      icon: Icons.receipt_long_rounded,
      actions: const [
        SheetAction(
          value: 'edit',
          label: 'Edit expense',
          icon: Icons.edit_outlined,
        ),
        SheetAction(
          value: 'delete',
          label: 'Delete expense',
          icon: Icons.delete_outline_rounded,
          destructive: true,
        ),
      ],
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'edit':
        await Get.toNamed<void>(
          AppRoutes.splitExpenseOf(group.id, expenseId: expense.id),
        );
      case 'delete':
        final ok = await AppBottomSheet.confirm(
          context,
          title: 'Delete this expense?',
          message:
              'It is removed from the group balances and from your '
              'activity.',
          confirmLabel: 'Delete expense',
          destructive: true,
          icon: Icons.delete_outline_rounded,
        );
        if (ok && context.mounted) {
          await _guard(context, () => _repo.deleteExpense(expense.id));
        }
    }
  }

  // --- Settlements ----------------------------------------------------------

  /// Records a payment, prefilled from [suggestion] when given.
  Future<void> settleUp(
    BuildContext context,
    SplitGroup group, {
    SplitTransfer? suggestion,
  }) async {
    final draft = await showSplitSheet<SettlementDraft>(
      context,
      SettleUpSheet(
        group: group,
        now: _clock.now(),
        fromId: suggestion?.fromId,
        toId: suggestion?.toId,
        amount: suggestion?.amount,
      ),
    );
    if (draft == null || !context.mounted) return;
    // The balances update in place, which confirms the payment.
    await _guard(
      context,
      () => _repo.saveSettlement(
        SplitSettlement(
          id: '',
          groupId: group.id,
          fromId: draft.fromId,
          toId: draft.toId,
          amount: draft.amount,
          occurredAt: draft.paidOn,
        ),
        method: draft.method,
      ),
    );
  }

  /// Actions on a recorded settlement: edit, delete.
  Future<void> openSettlement(
    BuildContext context,
    SplitGroup group,
    SplitSettlement settlement,
  ) async {
    final choice = await AppBottomSheet.actions<String>(
      context,
      title:
          '${group.nameOf(settlement.fromId)} paid '
          '${settlement.toId == SplitMember.youId ? 'you' : group.nameOf(settlement.toId)}',
      subtitle:
          '${_f.money(settlement.amount)} · '
          '${_f.fullDate(settlement.occurredAt)}',
      icon: Icons.handshake_rounded,
      actions: const [
        SheetAction(
          value: 'edit',
          label: 'Edit payment',
          icon: Icons.edit_outlined,
        ),
        SheetAction(
          value: 'delete',
          label: 'Delete payment',
          icon: Icons.delete_outline_rounded,
          destructive: true,
        ),
      ],
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'edit':
        final linked = await _repo.transactionFor(settlement.id);
        if (!context.mounted) return;
        final draft = await showSplitSheet<SettlementDraft>(
          context,
          SettleUpSheet(
            group: group,
            now: settlement.occurredAt,
            fromId: settlement.fromId,
            toId: settlement.toId,
            amount: settlement.amount,
            method: linked?.paymentMethod,
            editing: true,
          ),
        );
        if (draft != null && context.mounted) {
          await _guard(
            context,
            () => _repo.saveSettlement(
              SplitSettlement(
                id: settlement.id,
                groupId: group.id,
                fromId: draft.fromId,
                toId: draft.toId,
                amount: draft.amount,
                occurredAt: draft.paidOn,
              ),
              method: draft.method,
            ),
          );
        }
      case 'delete':
        final ok = await AppBottomSheet.confirm(
          context,
          title: 'Delete this payment?',
          message: 'The balances go back to what they were before it.',
          confirmLabel: 'Delete payment',
          destructive: true,
          icon: Icons.delete_outline_rounded,
        );
        if (ok && context.mounted) {
          await _guard(context, () => _repo.deleteSettlement(settlement.id));
        }
    }
  }
}
