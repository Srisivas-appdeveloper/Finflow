import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/motion/rolling_number.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/transaction.dart';
import 'category_style.dart';
import 'fin_card.dart';

/// Signed amount for a transaction: income in the income colour with `+`,
/// spending in the primary text colour with `−`, failed payments struck
/// through.
class TransactionAmount extends StatelessWidget {
  const TransactionAmount({
    super.key,
    required this.transaction,
    this.style,
    this.rolling = false,
  });

  final Transaction transaction;
  final TextStyle? style;

  /// Roll the digits into place (for prominent, single amounts).
  final bool rolling;

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final failed = transaction.status == TransactionStatus.failed;
    final text = Get.find<Formatters>().money(
      transaction.signedAmount,
      signed: true,
    );
    final resolved = (style ?? context.text.titleSmall!).tabular.copyWith(
      color: failed
          ? fin.textMuted
          : transaction.isCredit
          ? fin.income
          : fin.expense,
      decoration: failed ? TextDecoration.lineThrough : null,
    );
    if (rolling) return RollingNumberText(text, style: resolved);
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: resolved,
    );
  }
}

/// Small coloured label for a non-completed status. Always pairs colour with
/// an icon and text.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.dense = false});

  final TransactionStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final fg = switch (status) {
      TransactionStatus.completed => fin.income,
      TransactionStatus.pending => fin.pending,
      TransactionStatus.failed => fin.failed,
    };
    // Minimal: a coloured dot and tracked label, no filled pill.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dense ? 5 : 6,
          height: dense ? 5 : 6,
          decoration: BoxDecoration(
            color: fg,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: fg.withValues(alpha: 0.6), blurRadius: 6),
            ],
          ),
        ),
        SizedBox(width: dense ? 5 : 7),
        Text(
          status.label.toUpperCase(),
          style: context.text.eyebrow.copyWith(
            color: fg,
            fontSize: dense ? 9.5 : 10.5,
            letterSpacing: dense ? 1.2 : 1.8,
          ),
        ),
      ],
    );
  }
}

/// One row in a transaction list.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.heroTag,
    this.showDate = false,
  });

  final Transaction transaction;
  final VoidCallback? onTap;

  /// Tag for the avatar hero flight into the details page. Must be unique
  /// among visible tiles.
  final Object? heroTag;

  /// Show the date instead of only the time in the subtitle.
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    final t = transaction;
    final when = showDate
        ? '${f.dayMonth(t.occurredAt)}, ${f.time(t.occurredAt)}'
        : f.time(t.occurredAt);
    // Split spends say what part is the user's.
    final detail = t.share != null
        ? 'Your share ${f.money(t.share!)}'
        : t.paymentMethod == PaymentMethod.paidByOther
        ? 'Paid by a friend'
        : t.category.label;

    Widget avatar = CategoryAvatar(category: t.category);
    if (heroTag != null) avatar = Hero(tag: heroTag!, child: avatar);

    return Semantics(
      button: onTap != null,
      label:
          '${t.title}, ${t.isCredit ? 'received' : 'paid'} '
          '${f.money(t.amount)}, $detail, $when'
          '${t.status == TransactionStatus.completed ? '' : ', ${t.status.label}'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.control,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              children: [
                avatar,
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$detail · $when',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Cap the trailing column so large amounts or text scaling
                // shrink the amount instead of overflowing the row.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerEnd,
                        child: TransactionAmount(transaction: t),
                      ),
                      if (t.status != TransactionStatus.completed) ...[
                        const SizedBox(height: AppSpacing.xs),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerEnd,
                          child: StatusChip(status: t.status, dense: true),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum StatTone { neutral, positive, warning }

/// Compact card with an icon, label and a rolling value.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.tone = StatTone.neutral,
    this.onTap,
    this.delay = Duration.zero,
  });

  final IconData icon;
  final String label;
  final String value;
  final StatTone tone;
  final VoidCallback? onTap;

  /// Delay before the value starts rolling, to sequence with siblings.
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final colors = context.colors;
    final (fg, bg) = switch (tone) {
      StatTone.neutral => (colors.primary, colors.primaryContainer),
      StatTone.positive => (fin.income, fin.incomeContainer),
      StatTone.warning => (fin.pending, fin.pendingContainer),
    };
    return FinCard(
      onTap: onTap,
      semanticLabel: '$label: $value',
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.md),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [bg, Color.lerp(bg, fg, 0.18)!],
                ),
                boxShadow: [
                  BoxShadow(
                    color: fg.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, size: 18, color: fg),
            ),
            const SizedBox(height: AppSpacing.md),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: RollingNumberText(
                value,
                delay: delay,
                style: context.text.titleMedium?.tabular,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
