import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../shared/widgets/selection.dart';

import '../../app/routes/app_routes.dart';

import '../../core/motion/animated_widgets.dart';
import '../../core/motion/rolling_number.dart';
import '../../core/state/view_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../domain/entities/spending_summary.dart';
import '../../shared/widgets/category_breakdown.dart';
import '../../shared/widgets/decor/glass_orb.dart';
import '../../shared/widgets/fin_card.dart';
import '../../shared/widgets/financial_widgets.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/month_summary_card.dart';
import '../../shared/widgets/state_views.dart';
import '../split/split_controllers.dart';
import '../split/widgets/split_widgets.dart';
import '../shell/app_tab.dart';
import '../shell/shell_controller.dart';
import '../transaction_details/transaction_details_args.dart';
import 'home_controller.dart';
import 'widgets/weekly_spending_chart.dart';

class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => controller.load(showLoading: false),
      edgeOffset: MediaQuery.paddingOf(context).top,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Status-bar strip that frosts once content scrolls beneath it.
          const SliverAppBar(pinned: true, toolbarHeight: 0),
          SliverPadding(
            padding: pageInsets(
              context,
              maxWidth: 1080,
            ).copyWith(top: AppSpacing.lg),
            sliver: SliverToBoxAdapter(child: _Header(now: controller.now)),
          ),
          SliverPadding(
            padding: pageInsets(context, maxWidth: 1080).copyWith(
              top: AppSpacing.xxl,
              bottom: AppSpacing.xxxl + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverToBoxAdapter(
              child: Obx(
                () => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  switchInCurve: Curves.easeOut,
                  child: switch (controller.state.value) {
                    ViewLoading() => const _DashboardSkeleton(),
                    ViewError(:final message) => ErrorStateView(
                      message: message,
                      onRetry: controller.load,
                    ),
                    ViewEmpty() => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        EmptyStateView(
                          icon: Icons.receipt_long_outlined,
                          title: 'Start with your first transaction',
                          message:
                              'Add what you spend and earn. Your dashboard, '
                              'charts and insights build up from there.',
                          actionLabel: 'Add transaction',
                          onAction: () =>
                              Get.toNamed<void>(AppRoutes.addTransaction),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        FadeSlideIn(
                          index: 2,
                          child: SplitEntryCard(
                            overview: controller.split.value,
                          ),
                        ),
                      ],
                    ),
                    ViewData(:final data) => _Dashboard(
                      summary: data,
                      split: controller.split.value,
                    ),
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    final fin = context.fin;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MaskReveal(
                child: Text(
                  f.longDate(now).toUpperCase(),
                  style: context.text.eyebrow.copyWith(color: fin.accent),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              MaskReveal(
                delay: const Duration(milliseconds: 120),
                child: Semantics(
                  header: true,
                  child: Text(
                    Formatters.greeting(now),
                    style: context.text.greeting,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        GlassIconButton(
          icon: Icons.add_rounded,
          tooltip: 'Add transaction',
          size: 42,
          onPressed: () => Get.toNamed<void>(AppRoutes.addTransaction),
        ),
        IconButton(
          tooltip: 'Profile',
          onPressed: () => Get.find<ShellController>().select(AppTab.profile),
          icon: const GlassOrb(icon: Icons.person_rounded, size: 42),
        ),
      ],
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.summary, required this.split});

  final DashboardSummary summary;
  final SplitOverview? split;

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    final shell = Get.find<ShellController>();
    final s = summary;
    final month = f.monthName(s.month.month);

    final card = MonthSummaryCard(
      periodLabel: month,
      net: s.month.net,
      income: s.month.income,
      spending: s.month.spending,
      transactionCount: s.month.transactionCount,
    );

    final spend = _SpendHeadline(
      label: 'Spent in $month',
      amount: f.money(s.month.spending),
      caption: '${f.money(s.month.averageDailySpend)} a day on average',
    );

    final stats = _StatsRow(
      items: [
        ('Today', f.money(s.spentToday), null),
        ('Daily avg', f.money(s.month.averageDailySpend), null),
        ('Pending', '${s.pendingCount}', () => shell.select(AppTab.activity)),
      ],
    );

    // Headline figure and quick stats share one glass panel.
    final spendPanel = FinCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          spend,
          const SizedBox(height: AppSpacing.lg),
          stats,
        ],
      ),
    );

    final weekly = WeeklySpendingCard(
      days: s.lastSevenDays,
      total: s.lastSevenDaysTotal,
    );

    final categories = FinCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Where it went',
            subtitle: 'Top categories in $month',
            actionLabel: 'Insights',
            onAction: () => shell.select(AppTab.insights),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (s.topCategories.isEmpty)
            Text('No spending yet this month.', style: context.text.bodyMedium)
          else
            CategoryBreakdown(items: s.topCategories),
        ],
      ),
    );

    final recent = FinCard(
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
            child: SectionHeader(
              title: 'Recent activity',
              actionLabel: 'See all',
              onAction: () => shell.select(AppTab.activity),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < s.recent.length; i++) ...[
            if (i > 0)
              Divider(
                indent: 64,
                endIndent: AppSpacing.sm,
                color: context.fin.hairline,
              ),
            TransactionTile(
              transaction: s.recent[i],
              showDate: true,
              heroTag: 'home-${s.recent[i].id}',
              onTap: () => TransactionDetailsArgs.open(
                s.recent[i],
                heroTag: 'home-${s.recent[i].id}',
              ),
            ),
          ],
        ],
      ),
    );

    final splitEntry = SplitEntryCard(overview: split);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              card,
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(index: 6, child: spendPanel),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(index: 8, child: splitEntry),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(index: 10, child: weekly),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(index: 11, child: categories),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(index: 12, child: recent),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  card,
                  const SizedBox(height: AppSpacing.lg),
                  FadeSlideIn(index: 6, child: spendPanel),
                  const SizedBox(height: AppSpacing.lg),
                  FadeSlideIn(index: 8, child: splitEntry),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xl),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeSlideIn(index: 6, child: weekly),
                  const SizedBox(height: AppSpacing.lg),
                  FadeSlideIn(index: 8, child: categories),
                  const SizedBox(height: AppSpacing.lg),
                  FadeSlideIn(index: 10, child: recent),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Very large, very thin figure with the paise set smaller, under a tracked
/// label: the editorial centrepiece of the dashboard.
class _SpendHeadline extends StatelessWidget {
  const _SpendHeadline({
    required this.label,
    required this.amount,
    required this.caption,
  });

  final String label;
  final String amount;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final dot = amount.lastIndexOf('.');
    final whole = dot < 0 ? amount : amount.substring(0, dot);
    final fraction = dot < 0 ? '' : amount.substring(dot);
    final big = context.text.displayLarge!.tabular;

    return Semantics(
      label: '$label: $amount',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: context.text.eyebrow.copyWith(color: fin.accent),
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RollingNumberText(
                  whole,
                  delay: const Duration(milliseconds: 500),
                  duration: const Duration(milliseconds: 1600),
                  style: big,
                ),
                if (fraction.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 2),
                    child: RollingNumberText(
                      fraction,
                      delay: const Duration(milliseconds: 900),
                      style: big.copyWith(
                        fontSize: 26,
                        letterSpacing: -0.5,
                        color: fin.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              DelayedAnimationBuilder(
                delay: const Duration(milliseconds: 700),
                duration: const Duration(milliseconds: 1200),
                builder: (context, t, _) =>
                    Container(width: 40 * t, height: 1, color: fin.accent),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(caption, style: context.text.bodySmall)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Three figures separated by hairlines, without boxes.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.items});

  final List<(String, String, VoidCallback?)> items;

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: fin.hairline, width: 0.8)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                VerticalDivider(
                  width: 1,
                  thickness: 0.8,
                  indent: AppSpacing.md,
                  endIndent: AppSpacing.md,
                  color: fin.hairline,
                ),
              Expanded(
                child: _Stat(item: items[i], index: i),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.item, required this.index});

  final (String, String, VoidCallback?) item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final (label, value, onTap) = item;
    final fin = context.fin;
    return Semantics(
      button: onTap != null,
      label: '$label: $value',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.lg,
            horizontal: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label.toUpperCase(),
                textAlign: TextAlign.center,
                style: context.text.eyebrow.copyWith(color: fin.textMuted),
              ),
              const SizedBox(height: AppSpacing.sm),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: RollingNumberText(
                  value,
                  delay: Duration(milliseconds: 700 + 120 * index),
                  style: context.text.titleLarge!.tabular.copyWith(
                    fontFamily: AppTypography.sans,
                    fontWeight: FontWeight.w300,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, c) => SkeletonBox(
              height: c.maxWidth.clamp(0, 460) / 1.586,
              radius: 22,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl + 34),
          const SkeletonBox(width: 120, height: 10),
          const SizedBox(height: AppSpacing.md),
          const SkeletonBox(width: 240, height: 52),
          const SizedBox(height: AppSpacing.xxl),
          const SkeletonBox(height: 72, radius: AppRadii.md),
          const SizedBox(height: AppSpacing.xxl),
          const SkeletonBox(height: 248, radius: AppRadii.xxl),
        ],
      ),
    );
  }
}

/// Entry to Split: balances with friends and what is left this month.
class SplitEntryCard extends StatelessWidget {
  const SplitEntryCard({super.key, required this.overview});

  /// Null while loading.
  final SplitOverview? overview;

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    final fin = context.fin;
    final o = overview;
    final String headline;
    String? detail;
    if (o == null || o.ledgers.isEmpty) {
      headline = 'Share rent and bills with roommates';
      detail = 'See who owes whom and settle up';
    } else {
      final owed = o.owedToYou;
      final owe = o.youOwe;
      headline = owed.isPositive && owe.isPositive
          ? '${f.money(owed)} to collect · you owe ${f.money(owe)}'
          : owed.isPositive
          ? 'Friends owe you ${f.money(owed)}'
          : owe.isPositive
          ? 'You owe ${f.money(owe)}'
          : 'All settled up';
      detail = 'Left to save this month: ${f.money(o.month.net)}';
    }
    return FinCard(
      onTap: () => Get.toNamed<void>(AppRoutes.split),
      semanticLabel: 'Split with friends. $headline. $detail',
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ExcludeSemantics(
        child: Row(
          children: [
            const GroupOrb(size: 48),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SPLIT WITH FRIENDS',
                    style: context.text.eyebrow.copyWith(color: fin.accent),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(headline, style: context.text.titleSmall?.tabular),
                  const SizedBox(height: 2),
                  Text(detail, style: context.text.bodySmall?.tabular),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: fin.textMuted),
          ],
        ),
      ),
    );
  }
}
