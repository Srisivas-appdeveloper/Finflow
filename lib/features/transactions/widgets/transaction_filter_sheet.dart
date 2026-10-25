import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/entities/transaction_category.dart';
import '../../../domain/entities/transaction_filter.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/category_style.dart';
import '../../../shared/widgets/selection.dart';
import '../../../core/theme/app_colors.dart';

/// Advanced filter editor. Edits a draft and returns it only when the user
/// confirms, so dismissing the sheet discards changes. The confirm button
/// previews how many transactions the draft matches.
class TransactionFilterSheet extends StatefulWidget {
  const TransactionFilterSheet({
    super.key,
    required this.initial,
    required this.countFor,
  });

  final TransactionFilter initial;

  /// Number of results [TransactionFilter] would produce.
  final int Function(TransactionFilter) countFor;

  static Future<TransactionFilter?> show(
    BuildContext context,
    TransactionFilter initial, {
    required int Function(TransactionFilter) countFor,
  }) {
    return AppBottomSheet.show<TransactionFilter>(
      context,
      builder: (_) =>
          TransactionFilterSheet(initial: initial, countFor: countFor),
    );
  }

  @override
  State<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<TransactionFilterSheet> {
  late TransactionFilter _draft = widget.initial;

  static const _sortIcons = {
    TransactionSort.newest: Icons.south_rounded,
    TransactionSort.oldest: Icons.north_rounded,
    TransactionSort.highest: Icons.trending_up_rounded,
    TransactionSort.lowest: Icons.trending_down_rounded,
  };

  void _toggleCategory(TransactionCategory c) {
    final next = {..._draft.categories};
    next.contains(c) ? next.remove(c) : next.add(c);
    setState(() => _draft = _draft.copyWith(categories: next));
  }

  void _toggleStatus(TransactionStatus s) {
    final next = {..._draft.statuses};
    next.contains(s) ? next.remove(s) : next.add(s);
    setState(() => _draft = _draft.copyWith(statuses: next));
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final count = widget.countFor(_draft);
    final statusColors = {
      TransactionStatus.completed: fin.income,
      TransactionStatus.pending: fin.pending,
      TransactionStatus.failed: fin.failed,
    };

    return AppSheet(
      title: 'Filter & sort',
      subtitle: 'Refine your activity',
      icon: Icons.tune_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetSection(
            title: 'Sort by',
            child: LayoutBuilder(
              builder: (context, c) {
                final w = (c.maxWidth - AppSpacing.sm) / 2;
                return Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final sort in TransactionSort.values)
                      SizedBox(
                        width: w,
                        child: OptionTile(
                          icon: _sortIcons[sort]!,
                          label: sort.label,
                          selected: _draft.sort == sort,
                          onTap: () => setState(
                            () => _draft = _draft.copyWith(sort: sort),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          SheetSection(
            title: 'Category',
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final c in TransactionCategory.values)
                  GlassChip(
                    label: c.label,
                    icon: CategoryStyle.icon(c),
                    iconColor: CategoryStyle.color(context, c),
                    selected: _draft.categories.contains(c),
                    onTap: () => _toggleCategory(c),
                  ),
              ],
            ),
          ),
          SheetSection(
            title: 'Status',
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final s in TransactionStatus.values)
                  GlassChip(
                    label: s.label,
                    dotColor: statusColors[s],
                    selected: _draft.statuses.contains(s),
                    onTap: () => _toggleStatus(s),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
      actions: Row(
        children: [
          Expanded(
            child: AppButton(
              label: 'Reset',
              variant: AppButtonVariant.text,
              icon: Icons.restart_alt_rounded,
              onPressed: _draft.advancedCount == 0
                  ? null
                  : () => setState(() => _draft = _draft.resetAdvanced()),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: AppButton(
              label: count == 0
                  ? 'No results'
                  : 'Show $count ${count == 1 ? 'result' : 'results'}',
              icon: Icons.check_rounded,
              onPressed: count == 0
                  ? null
                  : () => Navigator.of(context).pop(_draft),
            ),
          ),
        ],
      ),
    );
  }
}
