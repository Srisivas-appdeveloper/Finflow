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
import '../../shared/widgets/fin_card.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/selection.dart';
import '../../shared/widgets/state_views.dart';
import 'card_actions.dart';
import 'cards_controller.dart';
import 'widgets/card_widgets.dart';

/// Cards tab: what's due across all cards, the cards themselves, bills to
/// pay and active EMIs.
class CardsPage extends GetView<CardsController> {
  const CardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = CardActions();
    return RefreshIndicator(
      onRefresh: () => controller.load(showLoading: false),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar.medium(
            pinned: true,
            title: const Text('Cards'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.lg),
                child: GlassIconButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Add credit card',
                  size: 42,
                  onPressed: () => actions.addCard(context),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: pageInsets(context).copyWith(
              bottom: AppSpacing.xxxl + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverToBoxAdapter(
              child: Obx(
                () => switch (controller.state.value) {
                  ViewLoading() => const Shimmer(
                    child: Column(
                      children: [
                        SkeletonBox(height: 140, radius: AppRadii.xxl),
                        SizedBox(height: AppSpacing.lg),
                        SkeletonBox(height: 200, radius: AppRadii.xxl),
                      ],
                    ),
                  ),
                  ViewError(:final message) => ErrorStateView(
                    message: message,
                    onRetry: controller.load,
                  ),
                  ViewEmpty() => EmptyStateView(
                    icon: Icons.credit_card_rounded,
                    title: 'Track your credit cards',
                    message:
                        'Add a card, then enter its bills and EMIs from your '
                        'statement. FinFlow shows what is due and reminds '
                        'you before the due date.',
                    actionLabel: 'Add a credit card',
                    onAction: () => actions.addCard(context),
                  ),
                  ViewData(:final data) => _Overview(
                    data: data,
                    actions: actions,
                  ),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.data, required this.actions});

  final CardsOverview data;
  final CardActions actions;

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    final fin = context.fin;
    final open = data.openBills;
    final cardsById = data.cardsById;
    final next = open.isEmpty ? null : open.first;

    final summary = FinCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DUE ON STATEMENTS',
            style: context.text.eyebrow.copyWith(color: fin.accent),
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RollingNumberText(
              f.money(data.totalDue),
              style: context.text.displayMedium!.tabular,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            next == null
                ? 'All bills are paid'
                : data.overdueCount > 0
                ? '${data.overdueCount} overdue · '
                      '${open.length} ${open.length == 1 ? 'bill' : 'bills'} open'
                : 'Next due ${f.relativeDay(next.dueDate, now: data.now)} · '
                      '${open.length} ${open.length == 1 ? 'bill' : 'bills'} open',
            style: context.text.bodyMedium?.copyWith(
              color: data.overdueCount > 0 ? fin.failed : null,
            ),
          ),
          if (data.activeEmis.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(color: fin.hairline),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: 18, color: fin.accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${data.activeEmis.length} active '
                    '${data.activeEmis.length == 1 ? 'EMI' : 'EMIs'}',
                    style: context.text.bodyMedium,
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${f.money(data.monthlyEmi)}/mo',
                      style: context.text.titleSmall?.tabular,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    final carousel = LayoutBuilder(
      builder: (context, constraints) {
        const fraction = 0.88;
        final height = constraints.maxWidth * fraction / 1.586;
        return SizedBox(
          height: height + 24,
          child: PageView.builder(
            controller: PageController(viewportFraction: fraction),
            padEnds: false,
            itemCount: data.cards.length,
            itemBuilder: (context, i) {
              final card = data.cards[i];
              return Padding(
                padding: const EdgeInsets.only(
                  right: AppSpacing.md,
                  bottom: 24,
                ),
                child: Semantics(
                  button: true,
                  label: 'Open ${card.name}',
                  child: PressableScale(
                    child: GestureDetector(
                      onTap: () => Get.toNamed<void>(AppRoutes.card(card.id)),
                      child: CardFace(card: card, now: data.now),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    final bills = FinCard(
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
            child: SectionHeader(title: 'Bills to pay'),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (open.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(
                'Nothing due. Add a bill from a card when your statement '
                'arrives.',
                style: context.text.bodyMedium,
              ),
            ),
          for (var i = 0; i < open.length; i++) ...[
            if (i > 0) Divider(indent: 64, color: fin.hairline),
            BillTile(
              bill: open[i],
              now: data.now,
              cardName: cardsById[open[i].cardId]?.name,
              onTap: () {
                final card = cardsById[open[i].cardId];
                if (card != null) actions.openBill(context, open[i], card);
              },
            ),
          ],
        ],
      ),
    );

    final emis = data.activeEmis;
    final emiCard = FinCard(
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
            child: SectionHeader(title: 'Active EMIs'),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < emis.length; i++) ...[
            if (i > 0) Divider(color: fin.hairline),
            EmiTile(
              plan: emis[i],
              now: data.now,
              onTap: () {
                final card = cardsById[emis[i].cardId];
                if (card != null) actions.openEmi(context, emis[i], card);
              },
            ),
          ],
        ],
      ),
    );

    final children = <Widget>[
      summary,
      carousel,
      bills,
      if (emis.isNotEmpty) emiCard,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Text(
          'Amounts come from what you enter. FinFlow does not connect to '
          'your bank or card issuer.',
          textAlign: TextAlign.center,
          style: context.text.bodySmall,
        ),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.lg),
          FadeSlideIn(index: i, child: children[i]),
        ],
      ],
    );
  }
}
