import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/state/view_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../domain/entities/credit_card.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/decor/ambient_background.dart';
import '../../shared/widgets/fin_card.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/state_views.dart';
import 'card_actions.dart';
import 'cards_controller.dart';
import 'widgets/card_widgets.dart';

class CardDetailsPage extends GetView<CardDetailsController> {
  const CardDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = CardActions();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Obx(() => Text(controller.card?.name ?? 'Card')),
        leading: const BackButton(),
        actions: [
          Obx(() {
            final card = controller.card;
            if (card == null) return const SizedBox.shrink();
            return IconButton(
              tooltip: 'Card options',
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () async {
                final choice = await AppBottomSheet.actions<String>(
                  context,
                  title: card.name,
                  icon: Icons.credit_card_rounded,
                  actions: const [
                    SheetAction(
                      value: 'edit',
                      label: 'Edit card',
                      icon: Icons.edit_outlined,
                    ),
                    SheetAction(
                      value: 'delete',
                      label: 'Delete card',
                      icon: Icons.delete_outline_rounded,
                      destructive: true,
                    ),
                  ],
                );
                if (!context.mounted) return;
                if (choice == 'edit') {
                  await actions.editCard(context, card);
                } else if (choice == 'delete' &&
                    await actions.deleteCard(context, card)) {
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
            ViewData(:final data) => _Details(data: data, actions: actions),
          },
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.data, required this.actions});

  final CardsOverview data;
  final CardActions actions;

  CreditCard get card => data.cards.first;

  String _ordinal(int d) {
    if (d >= 11 && d <= 13) return '${d}th';
    return switch (d % 10) {
      1 => '${d}st',
      2 => '${d}nd',
      3 => '${d}rd',
      _ => '${d}th',
    };
  }

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    final fin = context.fin;
    final utilisation = card.utilisation;
    final stale = card.isOutstandingStale(data.now);

    Widget sectionHeader(String title, String action, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, 0, AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: context.text.eyebrow.copyWith(color: fin.accent),
              ),
            ),
            AppButton(
              label: action,
              icon: Icons.add_rounded,
              size: AppButtonSize.small,
              variant: AppButtonVariant.text,
              onPressed: onTap,
            ),
          ],
        ),
      );
    }

    return ListView(
      addRepaintBoundaries: false,
      padding: pageInsets(context, maxWidth: 640).copyWith(
        top: MediaQuery.paddingOf(context).top + kToolbarHeight + AppSpacing.sm,
        bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xxxl,
      ),
      children: [
        CardFace(card: card, now: data.now),
        const SizedBox(height: AppSpacing.lg),
        FinCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current outstanding',
                          style: context.text.labelMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          card.currentOutstanding == null
                              ? 'Not set'
                              : f.money(card.currentOutstanding!),
                          style: context.text.titleLarge?.tabular,
                        ),
                        if (card.outstandingUpdatedAt != null)
                          Text(
                            '${stale ? 'Possibly out of date · ' : ''}'
                            'updated ${f.fullDate(card.outstandingUpdatedAt!)}',
                            style: context.text.bodySmall?.copyWith(
                              color: stale ? fin.pending : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                  AppButton.tonal(
                    label: 'Update',
                    size: AppButtonSize.small,
                    onPressed: () => actions.updateOutstanding(context, card),
                  ),
                ],
              ),
              if (utilisation != null) ...[
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: utilisation.clamp(0.0, 1.0),
                    minHeight: 6,
                    color: utilisation > 0.7 ? fin.pending : fin.accent,
                    backgroundColor: context.colors.onSurface.withValues(
                      alpha: 0.08,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${f.percent(utilisation)} of ${f.money(card.creditLimit)} used',
                  style: context.text.bodySmall,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Divider(color: fin.hairline),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Statement on the ${_ordinal(card.statementDay)} · '
                'payment due on the ${_ordinal(card.dueDay)}',
                style: context.text.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        sectionHeader(
          'Bills',
          'Add bill',
          () => actions.addBill(context, card),
        ),
        FinCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: data.bills.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'No bills yet. When your statement arrives, add its total '
                    'and minimum due and the due date.',
                    style: context.text.bodyMedium,
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < data.bills.length; i++) ...[
                      if (i > 0) Divider(indent: 64, color: fin.hairline),
                      BillTile(
                        bill: data.bills[i],
                        now: data.now,
                        onTap: () =>
                            actions.openBill(context, data.bills[i], card),
                      ),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.xl),
        sectionHeader('EMIs', 'Add EMI', () => actions.addEmi(context, card)),
        FinCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: data.emis.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'No EMIs. If you convert a purchase to instalments, add '
                    'it here to track what is left.',
                    style: context.text.bodyMedium,
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < data.emis.length; i++) ...[
                      if (i > 0) Divider(color: fin.hairline),
                      EmiTile(
                        plan: data.emis[i],
                        now: data.now,
                        onTap: () =>
                            actions.openEmi(context, data.emis[i], card),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
