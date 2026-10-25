import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/motion/animated_widgets.dart';
import '../../core/motion/rolling_number.dart';
import '../../core/state/view_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../domain/entities/money.dart';
import '../../domain/entities/split.dart';
import '../../domain/services/split_ledger.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/category_style.dart';
import '../../shared/widgets/decor/ambient_background.dart';
import '../../shared/widgets/fin_card.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/state_views.dart';
import 'split_actions.dart';
import 'split_controllers.dart';
import 'widgets/split_widgets.dart';

class SplitGroupPage extends GetView<SplitGroupController> {
  const SplitGroupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = SplitActions();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Obx(() => Text(controller.group?.name ?? 'Group')),
        leading: const BackButton(),
        actions: [
          Obx(() {
            final state = controller.state.value;
            if (state is! ViewData<SplitLedger>) {
              return const SizedBox.shrink();
            }
            return IconButton(
              tooltip: 'Share balances',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () => actions.share(context, state.data),
            );
          }),
          Obx(() {
            final group = controller.group;
            if (group == null) return const SizedBox.shrink();
            return IconButton(
              tooltip: 'Group options',
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () async {
                final choice = await AppBottomSheet.actions<String>(
                  context,
                  title: group.name,
                  icon: Icons.groups_rounded,
                  actions: const [
                    SheetAction(
                      value: 'edit',
                      label: 'Edit group and people',
                      icon: Icons.edit_outlined,
                    ),
                    SheetAction(
                      value: 'delete',
                      label: 'Delete group',
                      icon: Icons.delete_outline_rounded,
                      destructive: true,
                    ),
                  ],
                );
                if (!context.mounted) return;
                if (choice == 'edit') {
                  await actions.editGroup(context, group);
                } else if (choice == 'delete' &&
                    await actions.deleteGroup(context, group)) {
                  Get.back<void>();
                }
              },
            );
          }),
        ],
      ),
      body: AmbientBackground(
        objects: false,
        child: Obx(
          () => switch (controller.state.value) {
            ViewLoading() || ViewEmpty() => const LoadingView(),
            ViewError(:final message) => Padding(
              padding: pageInsets(context, maxWidth: 640),
              child: Center(
                child: controller.notFound.value
                    ? ErrorStateView(
                        icon: Icons.search_off_rounded,
                        title: 'Not found',
                        message: message,
                        retryLabel: 'Go back',
                        onRetry: () => Get.back<void>(),
                      )
                    : ErrorStateView(
                        message: message,
                        onRetry: controller.load,
                      ),
              ),
            ),
            ViewData(:final data) => Column(
              children: [
                Expanded(
                  child: _GroupBody(ledger: data, actions: actions),
                ),
                _ActionBar(ledger: data, actions: actions),
              ],
            ),
          },
        ),
      ),
    );
  }
}

class _GroupBody extends StatelessWidget {
  const _GroupBody({required this.ledger, required this.actions});

  final SplitLedger ledger;
  final SplitActions actions;

  SplitGroup get group => ledger.group;

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    final fin = context.fin;
    final mine = describeBalance(context, ledger.yourBalance, you: true);
    final count = ledger.expenses.length;

    final summary = FinCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR BALANCE',
            style: context.text.eyebrow.copyWith(color: fin.accent),
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RollingNumberText(
              f.money(ledger.yourBalance.abs()),
              style: context.text.displayMedium!.tabular.copyWith(
                color: ledger.yourBalance.isZero ? null : mine.color,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ledger.yourBalance.isZero
                ? 'You are settled up'
                : ledger.yourBalance.isPositive
                ? 'The group owes you'
                : 'You owe the group',
            style: context.text.titleSmall?.copyWith(color: mine.color),
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: fin.hairline),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${f.money(ledger.totalSpent)} spent together · $count '
            '${count == 1 ? 'expense' : 'expenses'} · '
            '${group.members.length + 1} people',
            style: context.text.bodyMedium,
          ),
        ],
      ),
    );

    Widget card(String title, List<Widget> rows, {String? empty}) => FinCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: SectionHeader(title: title),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (rows.isEmpty && empty != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(empty, style: context.text.bodyMedium),
            ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(indent: 64, color: fin.hairline),
            rows[i],
          ],
        ],
      ),
    );

    final settle = card(
      'Settle up',
      [
        for (final t in ledger.settleUp)
          PersonRow(
            group: group,
            memberId: t.fromId,
            subtitle:
                '${t.fromId == SplitMember.youId ? 'pay' : 'pays'} '
                '${t.toId == SplitMember.youId ? 'you' : group.nameOf(t.toId)} '
                '${f.money(t.amount)}',
            trailing: AppButton.tonal(
              label: 'Record',
              size: AppButtonSize.small,
              onPressed: () => actions.settleUp(context, group, suggestion: t),
            ),
          ),
      ],
      empty: count == 0
          ? 'Add an expense and FinFlow works out who should pay whom.'
          : 'Everyone is settled up.',
    );

    final balances = card('Balances', [
      for (final id in group.everyoneIds)
        PersonRow(
          group: group,
          memberId: id,
          trailing: _BalanceAmount(
            balance: ledger.balanceOf(id),
            you: id == SplitMember.youId,
          ),
        ),
    ]);

    final history = [
      for (final e in ledger.expenses) (e.occurredAt, e as Object),
      for (final s in ledger.settlements) (s.occurredAt, s as Object),
    ]..sort((a, b) => b.$1.compareTo(a.$1));

    final activity = card('Activity', [
      for (final (_, item) in history)
        switch (item) {
          SplitExpense e => _ExpenseTile(
            group: group,
            expense: e,
            onTap: () => actions.openExpense(context, group, e),
          ),
          SplitSettlement s => _SettlementTile(
            group: group,
            settlement: s,
            onTap: () => actions.openSettlement(context, group, s),
          ),
          _ => const SizedBox.shrink(),
        },
    ], empty: 'No expenses yet.');

    final children = [summary, settle, balances, activity];
    return ListView(
      addRepaintBoundaries: false,
      padding: pageInsets(context, maxWidth: 640).copyWith(
        top: MediaQuery.paddingOf(context).top + kToolbarHeight + AppSpacing.sm,
        bottom: AppSpacing.xl,
      ),
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.lg),
          FadeSlideIn(index: i, child: children[i]),
        ],
      ],
    );
  }
}

class _BalanceAmount extends StatelessWidget {
  const _BalanceAmount({required this.balance, required this.you});

  final Money balance;
  final bool you;

  @override
  Widget build(BuildContext context) {
    final b = describeBalance(context, balance, you: you);
    return TrailingAmount(text: b.text, color: b.color);
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.group,
    required this.expense,
    required this.onTap,
  });

  final SplitGroup group;
  final SplitExpense expense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    final e = expense;
    final yours = e.yourShare;
    final subtitle =
        '${group.nameOf(e.paidBy)} paid · ${f.dayMonth(e.occurredAt)}';
    final caption = yours.isZero
        ? 'Not in your share'
        : 'Your share ${f.money(yours)}';
    return Semantics(
      button: true,
      label: '${e.title}, ${f.money(e.amount)}, $subtitle, $caption',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.control,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            children: [
              CategoryAvatar(category: e.category, size: 40),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TrailingAmount(text: f.money(e.amount), caption: caption),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettlementTile extends StatelessWidget {
  const _SettlementTile({
    required this.group,
    required this.settlement,
    required this.onTap,
  });

  final SplitGroup group;
  final SplitSettlement settlement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    final s = settlement;
    final to = s.toId == SplitMember.youId ? 'you' : group.nameOf(s.toId);
    final title = '${group.nameOf(s.fromId)} paid $to';
    return Semantics(
      button: true,
      label: '$title, ${f.money(s.amount)}, ${f.fullDate(s.occurredAt)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.control,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            children: [
              PersonAvatar(group: group, memberId: s.fromId),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Settle up · ${f.dayMonth(s.occurredAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Neutral: the same row is money out for one person and in
              // for the other.
              TrailingAmount(text: f.money(s.amount)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pinned buttons: record a payment and add an expense.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.ledger, required this.actions});

  final SplitLedger ledger;
  final SplitActions actions;

  @override
  Widget build(BuildContext context) {
    final group = ledger.group;
    return SafeArea(
      top: false,
      child: Padding(
        padding: pageInsets(
          context,
          maxWidth: 640,
        ).copyWith(top: AppSpacing.sm, bottom: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: AppButton.tonal(
                label: 'Settle up',
                icon: Icons.handshake_outlined,
                expand: true,
                onPressed: () => actions.settleUp(
                  context,
                  group,
                  suggestion: ledger.settleUp.isEmpty
                      ? null
                      : ledger.settleUp.first,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppButton(
                label: 'Add expense',
                icon: Icons.add_rounded,
                expand: true,
                onPressed: () =>
                    Get.toNamed<void>(AppRoutes.splitExpenseOf(group.id)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
