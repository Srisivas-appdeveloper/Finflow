import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/motion/animated_widgets.dart';
import '../../core/motion/motion.dart';
import '../../core/motion/rolling_number.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/spending_summary.dart';
import 'category_style.dart';

/// Ranked list of spending categories. Each row is directly labelled with
/// name, amount and share, so colour is never the only way to identify a
/// category. Bar lengths are relative to the largest category.
class CategoryBreakdown extends StatelessWidget {
  const CategoryBreakdown({super.key, required this.items});

  final List<CategorySpend> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final largest = items.map((e) => e.share).reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.lg),
          _CategoryRow(
            item: items[i],
            relative: items[i].share / largest,
            index: i,
          ),
        ],
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.item,
    required this.relative,
    required this.index,
  });

  final CategorySpend item;
  final double relative;
  final int index;

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    final color = CategoryStyle.color(context, item.category);
    final label = CategoryStyle.label(item.category);
    final percent = f.percent(item.share);

    return Semantics(
      label: '$label: ${f.money(item.amount)}, $percent of spending',
      excludeSemantics: true,
      child: Row(
        children: [
          CategoryAvatar(category: item.category, size: 38),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerEnd,
                        child: RollingNumberText(
                          f.money(item.amount),
                          delay: Duration(milliseconds: 200 + 90 * index),
                          style: context.text.titleSmall?.tabular,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 3,
                          child: ColoredBox(
                            color: context.colors.surfaceContainerHigh,
                            child: DelayedAnimationBuilder(
                              value: relative,
                              delay: Duration(milliseconds: 150 + 90 * index),
                              duration: const Duration(milliseconds: 1100),
                              curve: AppMotion.settle,
                              builder: (context, v, _) => FractionallySizedBox(
                                alignment: AlignmentDirectional.centerStart,
                                widthFactor: v.clamp(0.0, 1.0),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    gradient: LinearGradient(
                                      colors: [
                                        color.withValues(alpha: 0.75),
                                        color,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 40),
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        widthFactor: 1,
                        child: RollingNumberText(
                          percent,
                          delay: Duration(milliseconds: 250 + 90 * index),
                          style: context.text.labelMedium?.tabular,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
