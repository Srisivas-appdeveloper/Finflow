import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';

import '../../core/motion/animated_widgets.dart';
import '../../core/motion/motion.dart';
import '../../core/motion/rolling_number.dart';
import '../../core/state/view_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../domain/entities/money.dart';
import '../../shared/widgets/category_breakdown.dart';
import '../../shared/widgets/fin_card.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/state_views.dart';
import 'insights_controller.dart';

class InsightsPage extends GetView<InsightsController> {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => controller.load(showLoading: false),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar.medium(
            pinned: true,
            title: const Text('Insights'),
            actions: [],
          ),
          SliverPadding(
            padding: pageInsets(context, maxWidth: 1080).copyWith(
              bottom: AppSpacing.xxxl + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverToBoxAdapter(
              child: Obx(
                () => switch (controller.state.value) {
                  ViewLoading() => const Shimmer(
                    child: Column(
                      children: [
                        SkeletonBox(height: 140, radius: AppRadii.xl),
                        SizedBox(height: AppSpacing.lg),
                        SkeletonBox(height: 320, radius: AppRadii.xl),
                      ],
                    ),
                  ),
                  ViewError(:final message) => ErrorStateView(
                    message: message,
                    onRetry: controller.load,
                  ),
                  ViewEmpty() => EmptyStateView(
                    icon: Icons.insights_rounded,
                    title: 'No insights yet',
                    message:
                        'Insights are calculated from your transactions. Add a '
                        'few and your patterns will show up here.',
                    actionLabel: 'Add transaction',
                    onAction: () => Get.toNamed<void>(AppRoutes.addTransaction),
                  ),
                  ViewData(:final data) => _Insights(data: data),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Insights extends StatelessWidget {
  const _Insights({required this.data});

  final InsightsData data;

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    final monthName = f.monthName(data.month.month);

    final overview = FinCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spent in $monthName', style: context.text.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: RollingNumberText(
              f.money(data.month.spending),
              delay: const Duration(milliseconds: 120),
              style: context.text.headlineMedium?.tabular,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ChangeLine(change: data.spendingChange),
          const SizedBox(height: AppSpacing.xl),
          _ComparisonBar(
            label: 'Income',
            amount: data.month.income,
            max: _max(data.month.income, data.month.spending),
            color: context.fin.income,
            delay: const Duration(milliseconds: 250),
          ),
          const SizedBox(height: AppSpacing.md),
          _ComparisonBar(
            label: 'Spending',
            amount: data.month.spending,
            max: _max(data.month.income, data.month.spending),
            color: context.fin.chartBar,
            delay: const Duration(milliseconds: 380),
          ),
        ],
      ),
    );

    final categories = FinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Spending by category',
            subtitle:
                '$monthName · ${data.categories.length} '
                '${data.categories.length == 1 ? 'category' : 'categories'}',
          ),
          const SizedBox(height: AppSpacing.lg),
          if (data.categories.isEmpty)
            Text('No spending yet this month.', style: context.text.bodyMedium)
          else
            CategoryBreakdown(items: data.categories),
        ],
      ),
    );

    final payees = FinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: 'Top payees', subtitle: monthName),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < data.payees.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${i + 1}',
                      style: context.text.labelLarge?.copyWith(
                        color: context.fin.textMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.payees[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall,
                        ),
                        Text(
                          '${data.payees[i].count} '
                          '${data.payees[i].count == 1 ? 'payment' : 'payments'}',
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    f.money(data.payees[i].amount),
                    style: context.text.titleSmall?.tabular,
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    FadeSlideIn(child: overview),
                    const SizedBox(height: AppSpacing.lg),
                    FadeSlideIn(index: 1, child: payees),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: FadeSlideIn(index: 1, child: categories)),
            ],
          );
        }
        final children = [overview, categories, payees];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(index: i, child: children[i]),
            ],
          ],
        );
      },
    );
  }

  InsightsController get controller => Get.find<InsightsController>();

  static Money _max(Money a, Money b) => a.minor >= b.minor ? a : b;
}

class _ChangeLine extends StatelessWidget {
  const _ChangeLine({required this.change});

  final double? change;

  @override
  Widget build(BuildContext context) {
    final style = context.text.bodySmall;
    final c = change;
    if (c == null) {
      return Text('No spending last month to compare with.', style: style);
    }
    final f = Get.find<Formatters>();
    final up = c >= 0;
    return Row(
      children: [
        Icon(
          up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 16,
          color: context.colors.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            '${f.percent(c.abs())} ${up ? 'more' : 'less'} than the same '
            'period last month',
            style: style,
          ),
        ),
      ],
    );
  }
}

class _ComparisonBar extends StatelessWidget {
  const _ComparisonBar({
    required this.label,
    required this.amount,
    required this.max,
    required this.color,
    required this.delay,
  });

  final String label;
  final Money amount;
  final Money max;
  final Color color;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    final ratio = max.isZero ? 0.0 : amount.minor / max.minor;
    return Semantics(
      label: '$label ${f.money(amount)}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: context.text.labelMedium)),
              RollingNumberText(
                f.money(amount),
                delay: delay,
                style: context.text.titleSmall?.tabular,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: ColoredBox(
                color: context.colors.surfaceContainerHigh,
                child: DelayedAnimationBuilder(
                  value: ratio,
                  delay: delay,
                  duration: const Duration(milliseconds: 1200),
                  curve: AppMotion.settle,
                  builder: (context, v, _) => FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: v.clamp(0.0, 1.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: [color.withValues(alpha: 0.7), color],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
