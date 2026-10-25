import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';

import '../../core/motion/animated_widgets.dart';
import '../../core/state/view_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../domain/entities/transaction.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/category_style.dart';
import '../../shared/widgets/decor/ambient_background.dart';
import '../../shared/widgets/fin_card.dart';
import '../../shared/widgets/financial_widgets.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/state_views.dart';
import '../split/split_actions.dart';
import 'transaction_details_controller.dart';

class TransactionDetailsPage extends GetView<TransactionDetailsController> {
  const TransactionDetailsPage({super.key});

  Future<void> _delete(BuildContext context) async {
    final linked = controller.transaction?.billId != null;
    final group = controller.split.value?.group;
    final ok = await AppBottomSheet.confirm(
      context,
      title: 'Delete this transaction?',
      message: linked
          ? 'This is a card bill payment. Deleting it also marks the bill as '
                'unpaid by this amount.'
          : group != null
          ? 'This is part of a split in ${group.name}. Deleting it also '
                'removes it from the group\'s balances.'
          : 'It is removed from your history and totals. This cannot be '
                'undone.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok) return;
    if (await controller.delete()) {
      Get.back<void>();
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\'t delete. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Transaction details'),
        leading: const BackButton(),
        actions: [
          Obx(() {
            final link = controller.split.value;
            // Settlements are edited from their group.
            if (controller.transaction == null || link?.settlement != null) {
              return const SizedBox.shrink();
            }
            final expense = link?.expense;
            return IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await Get.toNamed<void>(
                  expense != null
                      ? AppRoutes.splitExpenseOf(
                          link!.group.id,
                          expenseId: expense.id,
                        )
                      : AppRoutes.editTransactionOf(controller.id),
                );
                controller.load(showLoading: false);
              },
            );
          }),
          Obx(
            () => controller.transaction == null
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => _delete(context),
                  ),
          ),
        ],
      ),
      body: Obx(() {
        final state = controller.state.value;
        // Background glow takes on the transaction's category colour.
        return AmbientBackground(
          objects: false,
          accent: state is ViewData<Transaction>
              ? CategoryStyle.color(context, state.data.category)
              : null,
          child: switch (state) {
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
            ViewData(:final data) => _Details(
              transaction: data,
              link: controller.split.value,
            ),
          },
        );
      }),
    );
  }
}

class _Details extends GetView<TransactionDetailsController> {
  const _Details({required this.transaction, required this.link});

  final Transaction transaction;
  final SplitLink? link;

  Future<void> _split(BuildContext context) async {
    await SplitActions().splitTransaction(context, transaction);
    controller.load(showLoading: false);
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changeCategory(BuildContext context) async {
    final picked = await AppBottomSheet.choose(
      context,
      title: 'Change category',
      subtitle: 'Where should this be counted?',
      icon: Icons.label_rounded,
      options: controller.categoryOptions,
      selected: transaction.category,
      labelOf: (c) => c.label,
      leadingOf: (c) => CategoryAvatar(category: c, size: 36),
    );
    if (picked == null || !context.mounted) return;
    final ok = await controller.changeCategory(picked);
    if (context.mounted) {
      _snack(context, ok ? 'Category updated' : 'Couldn\'t update category');
    }
  }

  Future<void> _copyReference(BuildContext context, String reference) async {
    await Clipboard.setData(ClipboardData(text: reference));
    if (context.mounted) _snack(context, 'Reference copied');
  }

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    final t = transaction;
    final heroTag = controller.heroTag;

    Widget avatar = CategoryAvatar(category: t.category, size: 76);
    if (heroTag != null) avatar = Hero(tag: heroTag, child: avatar);
    final glow = CategoryStyle.color(context, t.category);

    return ListView(
      // Glass panels align their blurred backdrop slice on repaint, so list
      // items must not be cached in separate repaint boundaries.
      addRepaintBoundaries: false,
      padding: pageInsets(context, maxWidth: 640).copyWith(
        top: MediaQuery.paddingOf(context).top + AppSpacing.lg,
        bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xxxl,
      ),
      children: [
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              DelayedAnimationBuilder(
                duration: const Duration(milliseconds: 900),
                builder: (context, v, _) => Container(
                  width: 170 * (0.6 + 0.4 * v),
                  height: 170 * (0.6 + 0.4 * v),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        glow.withValues(alpha: 0.32 * v),
                        glow.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: glow.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: avatar,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FadeSlideIn(
          child: Column(
            children: [
              Text(
                t.title,
                textAlign: TextAlign.center,
                style: context.text.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: TransactionAmount(
                  transaction: t,
                  rolling: true,
                  style: context.text.displayMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              StatusChip(status: t.status),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${f.longDate(t.occurredAt)} · ${f.time(t.occurredAt)}',
                textAlign: TextAlign.center,
                style: context.text.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FadeSlideIn(
          index: 2,
          child: FinCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                _DetailRow(
                  icon: CategoryStyle.icon(t.category),
                  label: 'Category',
                  value: t.category.label,
                  onTap: controller.canChangeCategory
                      ? () => _changeCategory(context)
                      : null,
                  trailing: controller.canChangeCategory
                      ? const Icon(Icons.chevron_right_rounded)
                      : null,
                ),
                if (t.share != null)
                  _DetailRow(
                    icon: Icons.pie_chart_outline_rounded,
                    label: 'Your share',
                    value: f.money(t.share!),
                  ),
                if (link case final link?)
                  _DetailRow(
                    icon: Icons.groups_outlined,
                    label: 'Split with',
                    value: link.group.name,
                    onTap: () => Get.toNamed<void>(
                      AppRoutes.splitGroupOf(link.group.id),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                _DetailRow(
                  icon: t.isCredit
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  label: 'Type',
                  value: t.isCredit ? 'Money in' : 'Money out',
                ),
                if (t.paymentMethod == PaymentMethod.paidByOther &&
                    link?.expense != null)
                  _DetailRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Paid by',
                    value: link!.group.nameOf(link!.expense!.paidBy),
                  )
                else
                  _DetailRow(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Payment method',
                    value: t.paymentMethod.label,
                  ),
                _DetailRow(
                  icon: Icons.event_outlined,
                  label: 'Date',
                  value: f.fullDate(t.occurredAt),
                ),
                _DetailRow(
                  icon: Icons.schedule_outlined,
                  label: 'Time',
                  value: f.time(t.occurredAt),
                ),
                if (t.reference != null)
                  _DetailRow(
                    icon: Icons.tag_rounded,
                    label: 'Reference',
                    value: t.reference!,
                    trailing: IconButton(
                      tooltip: 'Copy reference',
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      onPressed: () => _copyReference(context, t.reference!),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (t.note != null) ...[
          const SizedBox(height: AppSpacing.lg),
          FadeSlideIn(
            index: 3,
            child: FinCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.sticky_note_2_outlined,
                    size: 20,
                    color: context.colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Note', style: context.text.labelMedium),
                        const SizedBox(height: AppSpacing.xs),
                        Text(t.note!, style: context.text.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (controller.canSplit) ...[
          const SizedBox(height: AppSpacing.xl),
          FadeSlideIn(
            index: 4,
            child: AppButton(
              label: 'Split with friends',
              icon: Icons.call_split_rounded,
              expand: true,
              onPressed: () => _split(context),
            ),
          ),
        ],
        if (controller.canChangeCategory) ...[
          SizedBox(height: controller.canSplit ? AppSpacing.md : AppSpacing.xl),
          FadeSlideIn(
            index: 4,
            child: Obx(
              () => AppButton.tonal(
                label: 'Change category',
                icon: Icons.label_outline_rounded,
                expand: true,
                loading: controller.saving.value,
                onPressed: () => _changeCategory(context),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            trailing == null ? AppSpacing.lg : AppSpacing.xs,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: context.colors.onSurfaceVariant),
              const SizedBox(width: AppSpacing.md),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.3,
                ),
                child: Text(
                  label,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: context.text.titleSmall?.tabular,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.xs),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
