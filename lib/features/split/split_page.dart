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
import '../../domain/services/split_ledger.dart';
import '../../shared/widgets/decor/ambient_background.dart';
import '../../shared/widgets/fin_card.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/selection.dart';
import '../../shared/widgets/state_views.dart';
import 'split_actions.dart';
import 'split_controllers.dart';
import 'widgets/split_widgets.dart';

/// Split: what friends owe and what is owed, what is left this month, and
/// the groups.
class SplitPage extends GetView<SplitOverviewController> {
  const SplitPage({super.key});

  Future<void> _create(BuildContext context, SplitActions actions) async {
    final group = await actions.createGroup(context);
    if (group != null) {
      await Get.toNamed<void>(AppRoutes.splitGroupOf(group.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = SplitActions();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Split'),
        leading: const BackButton(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: GlassIconButton(
              icon: Icons.group_add_rounded,
              tooltip: 'New group',
              size: 42,
              onPressed: () => _create(context, actions),
            ),
          ),
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
                child: ErrorStateView(
                  message: message,
                  onRetry: controller.load,
                ),
              ),
            ),
            ViewData(:final data) => _Overview(
              data: data,
              onCreate: () => _create(context, actions),
            ),
          },
        ),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.data, required this.onCreate});

  final SplitOverview data;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (data.ledgers.isNotEmpty) _Balances(data: data),
      _LeftThisMonth(data: data),
      if (data.ledgers.isEmpty)
        EmptyStateView(
          icon: Icons.groups_rounded,
          title: 'Split with roommates',
          message:
              'Make a group for your room, flat or trip. Add what each '
              'person paid and FinFlow works out who owes whom.',
          actionLabel: 'Create a group',
          onAction: onCreate,
        )
      else
        _Groups(ledgers: data.ledgers),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Text(
          'Groups are kept on this phone only. Share a summary to let the '
          'others know where things stand.',
          textAlign: TextAlign.center,
          style: context.text.bodySmall,
        ),
      ),
    ];
    return ListView(
      addRepaintBoundaries: false,
      padding: pageInsets(context, maxWidth: 640).copyWith(
        top: MediaQuery.paddingOf(context).top + kToolbarHeight + AppSpacing.sm,
        bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xxxl,
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

/// Owed to you and you owe, across all groups.
class _Balances extends StatelessWidget {
  const _Balances({required this.data});

  final SplitOverview data;

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    final fin = context.fin;

    Widget figure(String label, String value, Color color) {
      return Expanded(
        child: Semantics(
          label: '$label: $value',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: context.text.eyebrow.copyWith(color: fin.textMuted),
              ),
              const SizedBox(height: AppSpacing.sm),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: RollingNumberText(
                  value,
                  style: context.text.headlineSmall!.tabular.copyWith(
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FinCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ACROSS YOUR GROUPS',
            style: context.text.eyebrow.copyWith(color: fin.accent),
          ),
          const SizedBox(height: AppSpacing.lg),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                figure(
                  'Owed to you',
                  f.money(data.owedToYou),
                  data.owedToYou.isZero ? context.colors.onSurface : fin.income,
                ),
                VerticalDivider(width: AppSpacing.xl, color: fin.hairline),
                figure(
                  'You owe',
                  f.money(data.youOwe),
                  data.youOwe.isZero ? context.colors.onSurface : fin.pending,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// This month's income minus the user's own spending: what can be saved or
/// invested once everyone has settled up.
class _LeftThisMonth extends StatelessWidget {
  const _LeftThisMonth({required this.data});

  final SplitOverview data;

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    final fin = context.fin;
    final month = data.month;
    final left = month.net;

    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.text.bodyMedium)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(value, style: context.text.titleSmall?.tabular),
            ),
          ),
        ],
      ),
    );

    return FinCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'LEFT TO SAVE OR INVEST · ${f.monthName(month.month).toUpperCase()}',
            style: context.text.eyebrow.copyWith(color: fin.accent),
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RollingNumberText(
              f.money(left),
              style: context.text.displaySmall!.tabular.copyWith(
                color: left.isNegative ? fin.failed : null,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          line('Income', f.money(month.income)),
          line('Your spending', '−${f.money(month.spending)}'),
          const SizedBox(height: AppSpacing.md),
          Text(
            left.isNegative
                ? 'You have spent more than you earned this month.'
                : 'Only your share of split bills counts as your spending, '
                      'so this is what is left once everyone settles up.',
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Groups extends StatelessWidget {
  const _Groups({required this.ledgers});

  final List<SplitLedger> ledgers;

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return FinCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: SectionHeader(title: 'Groups'),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < ledgers.length; i++) ...[
            if (i > 0) Divider(indent: 64, color: fin.hairline),
            _GroupTile(ledger: ledgers[i]),
          ],
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.ledger});

  final SplitLedger ledger;

  @override
  Widget build(BuildContext context) {
    final g = ledger.group;
    final people = g.members.length + 1;
    final count = ledger.expenses.length;
    final you = ledger.yourBalance;
    final balance = describeBalance(context, you, you: true);
    return Semantics(
      button: true,
      label:
          '${g.name}, $people people, $count '
          '${count == 1 ? 'expense' : 'expenses'}, ${balance.text}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: AppRadii.control,
        onTap: () => Get.toNamed<void>(AppRoutes.splitGroupOf(g.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            children: [
              const GroupOrb(size: 44),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$people people · $count '
                      '${count == 1 ? 'expense' : 'expenses'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Amount over a short caption, so the group's details keep
              // their room.
              TrailingAmount(
                text: you.isZero
                    ? 'Settled'
                    : Get.find<Formatters>().money(you.abs()),
                caption: you.isZero
                    ? null
                    : you.isPositive
                    ? 'you get back'
                    : 'you owe',
                color: balance.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
