import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/card_bill.dart';
import '../../../domain/entities/credit_card.dart';
import '../../../domain/entities/emi_plan.dart';

/// Gradients a card face can use (chosen by [CreditCard.styleIndex]).
abstract final class CardStyles {
  static const gradients = <List<Color>>[
    [Color(0xFF6D28D9), Color(0xFFC026D3), Color(0xFFF97316)],
    [Color(0xFF1D4ED8), Color(0xFF0891B2), Color(0xFF22D3EE)],
    [Color(0xFF047857), Color(0xFF0D9488), Color(0xFF84CC16)],
    [Color(0xFF111827), Color(0xFF374151), Color(0xFF6B7280)],
  ];

  static LinearGradient of(int index) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: gradients[index % gradients.length],
  );
}

/// Visual credit card. Shows what the user entered; the available limit
/// appears only when an outstanding balance is known, with its date.
class CardFace extends StatelessWidget {
  const CardFace({super.key, required this.card, this.now});

  final CreditCard card;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    const white = Colors.white;
    final muted = Colors.white.withValues(alpha: 0.78);
    final eyebrow = context.text.eyebrow.copyWith(color: muted);
    final available = card.availableLimit;
    final stale = now != null && card.isOutstandingStale(now!);

    return AspectRatio(
      aspectRatio: 1.586,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: CardStyles.of(card.styleIndex),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: CardStyles
                  .gradients[card.styleIndex % CardStyles.gradients.length][1]
                  .withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Glass highlight.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [
                      Colors.white.withValues(alpha: 0.2),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          card.issuer.isEmpty
                              ? 'CREDIT CARD'
                              : card.issuer.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: eyebrow,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Icon(Icons.contactless_outlined, color: muted, size: 22),
                    ],
                  ),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      card.name,
                      style: context.text.titleLarge!.copyWith(color: white),
                    ),
                  ),
                  if (card.last4 != null)
                    Text(
                      '•••• ${card.last4}',
                      style: context.text.titleSmall!.tabular.copyWith(
                        color: muted,
                        letterSpacing: 2,
                      ),
                    ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _Figure(
                          label: 'LIMIT',
                          value: f.moneyCompact(card.creditLimit),
                        ),
                      ),
                      Expanded(
                        child: _Figure(
                          label: available == null
                              ? 'AVAILABLE'
                              : 'AVAILABLE${stale ? ' · OLD' : ''}',
                          value: available == null
                              ? 'Not set'
                              : f.moneyCompact(available),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: context.text.eyebrow.copyWith(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: 9.5,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: context.text.titleMedium!.tabular.copyWith(
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// Colour and label for a bill's state, including overdue.
(Color, String) billStatusLook(
  BuildContext context,
  CardBill bill,
  DateTime now,
) {
  final fin = context.fin;
  if (bill.isOverdue(now)) return (fin.failed, 'Overdue');
  return switch (bill.status) {
    BillStatus.paid => (fin.income, BillStatus.paid.label),
    BillStatus.minimumPaid => (fin.pending, BillStatus.minimumPaid.label),
    BillStatus.partiallyPaid => (fin.pending, BillStatus.partiallyPaid.label),
    BillStatus.unpaid => (fin.accent, BillStatus.unpaid.label),
  };
}

/// One bill: card, due date (with days left), remaining amount and status.
class BillTile extends StatelessWidget {
  const BillTile({
    super.key,
    required this.bill,
    required this.now,
    this.cardName,
    this.onTap,
  });

  final CardBill bill;
  final DateTime now;
  final String? cardName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    final (color, label) = billStatusLook(context, bill, now);
    final days = bill.daysUntilDue(now);
    final when = bill.isSettled
        ? 'Statement ${f.dayMonth(bill.statementDate)}'
        : days == 0
        ? 'Due today'
        : days > 0
        ? 'Due in $days ${days == 1 ? 'day' : 'days'} · ${f.dayMonth(bill.dueDate)}'
        : 'Was due ${f.dayMonth(bill.dueDate)}';

    return Semantics(
      button: onTap != null,
      label:
          '${cardName ?? 'Card'} bill, ${f.money(bill.totalDue)}, $label, $when',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.control,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Icon(Icons.receipt_long_rounded, color: color, size: 21),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cardName ?? f.monthYear(bill.statementDate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      when,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: bill.isOverdue(now) ? context.fin.failed : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.38,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        f.money(
                          bill.isSettled ? bill.totalDue : bill.remaining,
                        ),
                        style: context.text.titleSmall?.tabular,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label.toUpperCase(),
                      style: context.text.eyebrow.copyWith(
                        color: color,
                        fontSize: 9.5,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One EMI plan with a progress bar of instalments due so far.
class EmiTile extends StatelessWidget {
  const EmiTile({super.key, required this.plan, required this.now, this.onTap});

  final EmiPlan plan;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    final fin = context.fin;
    final due = plan.instalmentsDue(now);
    final next = plan.nextDueDate(now);
    final progress = plan.tenureMonths == 0 ? 0.0 : due / plan.tenureMonths;
    final subtitle = plan.isClosed
        ? 'Closed early on ${f.fullDate(plan.closedOn!)}'
        : next == null
        ? 'All ${plan.tenureMonths} instalments done'
        : 'Next ${f.dayMonth(next)} · ${plan.instalmentsRemaining(now)} left';

    return Semantics(
      button: onTap != null,
      label:
          '${plan.title}, ${f.money(plan.instalment)} a month, '
          '$due of ${plan.tenureMonths} instalments due, $subtitle',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.control,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                  ),
                  Text(
                    '${f.money(plan.instalment)}/mo',
                    style: context.text.titleSmall?.tabular,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: plan.isClosed ? 1 : progress,
                  minHeight: 6,
                  backgroundColor: context.colors.onSurface.withValues(
                    alpha: 0.08,
                  ),
                  color: plan.isClosed ? fin.textMuted : fin.accent,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall,
                    ),
                  ),
                  Text(
                    '$due/${plan.tenureMonths}',
                    style: context.text.labelMedium?.tabular,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
