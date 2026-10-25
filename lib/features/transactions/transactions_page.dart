import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';

import '../../core/motion/animated_widgets.dart';
import '../../core/motion/motion.dart';
import '../../core/state/view_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../domain/entities/spending_summary.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_filter.dart';
import '../../shared/widgets/app_inputs.dart';
import '../../shared/widgets/financial_widgets.dart';
import '../../shared/widgets/glass.dart';
import '../../shared/widgets/selection.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/state_views.dart';
import '../transaction_details/transaction_details_args.dart';
import 'transactions_controller.dart';
import 'widgets/transaction_filter_sheet.dart';

class TransactionsPage extends GetView<TransactionsController> {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final insets = pageInsets(context);
    return RefreshIndicator(
      onRefresh: () => controller.load(showLoading: false),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar.medium(
            pinned: true,
            title: const Text('Transactions'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.lg),
                child: GlassIconButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Add transaction',
                  size: 42,
                  onPressed: () => Get.toNamed<void>(AppRoutes.addTransaction),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: insets,
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSearchField(
                    controller: controller.searchController,
                    onChanged: controller.onSearchChanged,
                    hint: 'Search payee, category or note',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Obx(() => _FilterBar(filter: controller.filter.value)),
                ],
              ),
            ),
          ),
          Obx(() {
            final state = controller.state.value;
            return switch (state) {
              ViewLoading() => SliverPadding(
                padding: insets.copyWith(top: AppSpacing.md),
                sliver: const SliverToBoxAdapter(
                  child: TransactionListSkeleton(count: 8),
                ),
              ),
              ViewError(:final message) => SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: insets,
                  child: ErrorStateView(
                    message: message,
                    onRetry: controller.load,
                  ),
                ),
              ),
              ViewEmpty() => SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: insets,
                  child: EmptyStateView(
                    icon: Icons.receipt_long_rounded,
                    title: 'No transactions yet',
                    message:
                        'Everything you add appears here, grouped by day, with '
                        'search and filters.',
                    actionLabel: 'Add transaction',
                    onAction: () => Get.toNamed<void>(AppRoutes.addTransaction),
                  ),
                ),
              ),
              ViewData(:final data) when data.isEmpty => SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: insets,
                  child: EmptyStateView(
                    icon: Icons.search_off_rounded,
                    title: 'No matches',
                    message: 'No transactions match your search or filters.',
                    actionLabel: 'Clear filters',
                    onAction: controller.clearAll,
                  ),
                ),
              ),
              ViewData(:final data) => _ResultsSliver(
                results: data,
                insets: insets,
              ),
            };
          }),
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends GetView<TransactionsController> {
  const _FilterBar({required this.filter});

  final TransactionFilter filter;

  static const _labels = {
    DirectionFilter.all: 'All',
    DirectionFilter.spending: 'Spending',
    DirectionFilter.income: 'Income',
  };

  static const _icons = {
    DirectionFilter.all: Icons.apps_rounded,
    DirectionFilter.spending: Icons.north_east_rounded,
    DirectionFilter.income: Icons.south_west_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final count = filter.advancedCount;
    return Row(
      children: [
        Expanded(
          child: GlassSegmented<DirectionFilter>(
            segments: [
              for (final d in DirectionFilter.values)
                (d, _labels[d]!, _icons[d]),
            ],
            selected: filter.direction,
            onChanged: controller.setDirection,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Badge(
          isLabelVisible: count > 0,
          label: Text('$count'),
          child: GlassIconButton(
            tooltip: count > 0 ? 'Filters ($count active)' : 'Filters',
            icon: Icons.tune_rounded,
            active: count > 0,
            onPressed: () async {
              final result = await TransactionFilterSheet.show(
                context,
                filter,
                countFor: controller.previewCount,
              );
              if (result != null) controller.applyAdvanced(result);
            },
          ),
        ),
      ],
    );
  }
}

/// Flattened list of day headers and tiles, built lazily.
/// Results as glass panels: one per day (long days and ungrouped lists are
/// split into panels of at most [_chunk] rows so the list stays lazy).
class _ResultsSliver extends StatelessWidget {
  const _ResultsSliver({required this.results, required this.insets});

  final TransactionResults results;
  final EdgeInsets insets;

  static const _chunk = 10;

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    final ungrouped = results.groups.first.day == null;
    final panels = <_Panel>[];
    for (final g in results.groups) {
      for (var start = 0; start < g.transactions.length; start += _chunk) {
        panels.add(
          _Panel(
            header: start == 0 ? g : null,
            rows: g.transactions.sublist(
              start,
              (start + _chunk).clamp(0, g.transactions.length),
            ),
          ),
        );
      }
    }

    return SliverPadding(
      padding: insets.copyWith(top: AppSpacing.sm),
      sliver: SliverList.builder(
        // Glass panels align their backdrop slice when repainted.
        addRepaintBoundaries: false,
        itemCount: panels.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xs,
                bottom: AppSpacing.sm,
              ),
              child: Text(
                '${results.count} '
                '${results.count == 1 ? 'transaction' : 'transactions'}'
                ' · Net ${f.money(results.net, signed: true)}',
                style: context.text.bodySmall?.tabular,
              ),
            );
          }
          final panel = panels[i - 1];
          // The first screenful cascades in; panels keep their entrance
          // state by identity, so filtering only animates new ones.
          return FadeSlideIn(
            key: ValueKey(panel.rows.first.id),
            index: i < 6 ? i : 0,
            duration: i < 6 ? AppMotion.long : Duration.zero,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Glass(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (panel.header != null) _DayHeader(group: panel.header!),
                    for (var r = 0; r < panel.rows.length; r++) ...[
                      if (r > 0)
                        Divider(
                          indent: 60,
                          endIndent: AppSpacing.sm,
                          color: context.fin.hairline,
                        ),
                      TransactionTile(
                        transaction: panel.rows[r],
                        heroTag: 'list-${panel.rows[r].id}',
                        // Ungrouped (amount-sorted) lists have no day headers.
                        showDate: ungrouped,
                        onTap: () => TransactionDetailsArgs.open(
                          panel.rows[r],
                          heroTag: 'list-${panel.rows[r].id}',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Panel {
  const _Panel({required this.header, required this.rows});
  final TransactionDayGroup? header;
  final List<Transaction> rows;
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.group});

  final TransactionDayGroup group;

  @override
  Widget build(BuildContext context) {
    final day = group.day;
    if (day == null) return const SizedBox(height: AppSpacing.sm);
    final f = Get.find<Formatters>();
    final now = Get.find<AppClock>().now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Expanded(
              child: Text(
                f.relativeDay(day, now: now),
                style: context.text.labelLarge?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              f.money(group.net, signed: true),
              style: context.text.labelMedium?.tabular,
            ),
          ],
        ),
      ),
    );
  }
}
