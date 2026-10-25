import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_environment.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../domain/entities/split.dart';
import '../../domain/entities/transaction.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_inputs.dart';
import '../../shared/widgets/category_style.dart';
import '../../shared/widgets/decor/ambient_background.dart';
import '../../shared/widgets/fin_card.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/selection.dart';
import '../../shared/widgets/state_views.dart';
import 'split_expense_form_controller.dart';
import 'widgets/split_widgets.dart';

class SplitExpenseFormPage extends GetView<SplitExpenseFormController> {
  const SplitExpenseFormPage({super.key});

  static const _methodIcons = {
    PaymentMethod.upi: Icons.qr_code_2_rounded,
    PaymentMethod.card: Icons.credit_card_rounded,
    PaymentMethod.bankTransfer: Icons.account_balance_rounded,
    PaymentMethod.cash: Icons.payments_outlined,
    PaymentMethod.wallet: Icons.account_balance_wallet_outlined,
  };

  Future<void> _save(BuildContext context) async {
    FocusScope.of(context).unfocus();
    try {
      final saved = await controller.save();
      if (saved == null) return;
      Get.back<SplitExpense>(result: saved);
    } on ArgumentError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message?.toString() ?? 'Please check the details'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t save. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final symbol = Get.find<Formatters>().currencySymbol(
      Get.find<AppEnvironment>().currencyCode,
    );
    final now = DateTime.now();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          controller.isEditing
              ? 'Edit expense'
              : controller.transactionId != null
              ? 'Split this spend'
              : 'Add expense',
        ),
        leading: const CloseButton(),
      ),
      body: AmbientBackground(
        objects: false,
        child: Obx(() {
          if (controller.loading.value) return const LoadingView();
          final error = controller.loadError.value;
          final group = controller.group.value;
          if (error != null || group == null) {
            return Padding(
              padding: pageInsets(context, maxWidth: 640),
              child: Center(
                child: ErrorStateView(
                  icon: Icons.search_off_rounded,
                  title: 'Not found',
                  message: error ?? 'This group no longer exists.',
                  retryLabel: 'Go back',
                  onRetry: () => Get.back<void>(),
                ),
              ),
            );
          }
          final youPaid = controller.paidBy.value == SplitMember.youId;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  addRepaintBoundaries: false,
                  padding: pageInsets(context, maxWidth: 640).copyWith(
                    top: MediaQuery.paddingOf(context).top + kToolbarHeight,
                    bottom: AppSpacing.xl,
                  ),
                  children: [
                    FinCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const GroupOrb(size: 32),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  group.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.titleSmall,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AmountField(
                            controller: controller.amount,
                            currencySymbol: symbol,
                            label: 'Total amount',
                            errorText: controller.amountError.value,
                            onChanged: controller.onAmountChanged,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: controller.title,
                            label: 'What was it for?',
                            hint: 'e.g. Rent, groceries, electricity',
                            prefixIcon: Icons.receipt_long_outlined,
                            errorText: controller.titleError.value,
                            onChanged: controller.onTitleChanged,
                            textInputAction: TextInputAction.next,
                          ),
                        ],
                      ),
                    ),
                    FormSection(
                      label: 'Paid by',
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final id in controller.people)
                            GlassChip(
                              label: group.nameOf(id),
                              selected: controller.paidBy.value == id,
                              onTap: () => controller.paidBy.value = id,
                            ),
                        ],
                      ),
                    ),
                    if (youPaid)
                      FormSection(
                        label: 'You paid with',
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (final m in PaymentMethod.selectable)
                              GlassChip(
                                label: m.label,
                                icon: _methodIcons[m],
                                selected: controller.method.value == m,
                                onTap: () => controller.method.value = m,
                              ),
                          ],
                        ),
                      ),
                    FormSection(
                      label: 'Split',
                      child: _SplitEditor(controller: controller),
                    ),
                    FormSection(
                      label: 'Category',
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final c in controller.categories)
                            GlassChip(
                              label: c.label,
                              icon: CategoryStyle.icon(c),
                              iconColor: CategoryStyle.color(context, c),
                              selected: controller.category.value == c,
                              onTap: () => controller.category.value = c,
                            ),
                        ],
                      ),
                    ),
                    FormSection(
                      label: 'When',
                      child: DateField(
                        label: 'Date and time',
                        value: controller.occurredAt.value,
                        withTime: true,
                        lastDate: DateTime(now.year + 1, 12, 31),
                        onChanged: (v) => controller.occurredAt.value = v,
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: pageInsets(
                    context,
                    maxWidth: 640,
                  ).copyWith(top: AppSpacing.sm, bottom: AppSpacing.md),
                  child: AppButton(
                    label: controller.isEditing ? 'Save changes' : 'Save split',
                    icon: Icons.check_rounded,
                    expand: true,
                    loading: controller.saving.value,
                    onPressed: () => _save(context),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// Mode switch, one row per person, and a live summary of the split.
class _SplitEditor extends StatelessWidget {
  const _SplitEditor({required this.controller});

  final SplitExpenseFormController controller;

  @override
  Widget build(BuildContext context) {
    // Its own Obx: mode, selections and amounts are read here, not in the
    // page's builder.
    return Obx(() => _build(context));
  }

  Widget _build(BuildContext context) {
    final f = Get.find<Formatters>();
    final fin = context.fin;
    final group = controller.group.value!;
    final mode = controller.mode.value;
    final shares = controller.shares();
    final symbol = f.currencySymbol(controller.currencyCode);
    final yours = shares[SplitMember.youId];
    final unassigned = mode == SplitMode.amounts ? controller.unassigned : null;
    final error = controller.splitError.value;

    Widget row(String id) {
      final amount = shares[id];
      final amountText = amount == null ? '—' : f.money(amount);
      return switch (mode) {
        SplitMode.equal => PersonRow(
          group: group,
          memberId: id,
          onTap: () => controller.toggle(id),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TrailingAmount(text: amountText),
              Checkbox(
                value: controller.included.contains(id),
                onChanged: (_) => controller.toggle(id),
                semanticLabel: 'Include ${group.nameOf(id)}',
              ),
            ],
          ),
        ),
        SplitMode.shares => PersonRow(
          group: group,
          memberId: id,
          subtitle: amountText,
          trailing: _Stepper(
            value: controller.units[id] ?? 0,
            name: group.nameOf(id),
            onChanged: (v) => controller.setUnits(id, v),
          ),
        ),
        SplitMode.amounts => PersonRow(
          group: group,
          memberId: id,
          trailing: SizedBox(
            width: 132,
            child: AmountField(
              controller: controller.personAmount(id),
              currencySymbol: symbol,
              label: group.nameOf(id),
              large: false,
              onChanged: controller.onPersonAmountChanged,
            ),
          ),
        ),
      };
    }

    final String summary;
    Color? summaryColor;
    if (unassigned != null && !unassigned.isZero) {
      summary = unassigned.isNegative
          ? '${f.money(unassigned.abs())} more than the total'
          : '${f.money(unassigned)} left to split';
      summaryColor = fin.pending;
    } else if (yours == null || yours.isZero) {
      summary = shares.isEmpty
          ? 'Enter the total to see each person\'s share'
          : 'You are not part of this split';
    } else {
      summary = 'Your share is ${f.money(yours)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassSegmented<SplitMode>(
          segments: const [
            (SplitMode.equal, 'Equally', null),
            (SplitMode.amounts, 'Amounts', null),
            (SplitMode.shares, 'Shares', null),
          ],
          selected: mode,
          onChanged: controller.setMode,
        ),
        const SizedBox(height: AppSpacing.md),
        FinCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            children: [
              for (var i = 0; i < controller.people.length; i++) ...[
                if (i > 0) Divider(indent: 56, color: fin.hairline),
                row(controller.people[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Summary(
          text: error ?? summary,
          color: error != null ? context.colors.error : summaryColor,
          icon: error != null
              ? Icons.error_outline_rounded
              : Icons.pie_chart_outline_rounded,
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.text, required this.icon, this.color});

  final String text;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? context.fin.accent;
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: context.text.titleSmall?.tabular.copyWith(
                color: color ?? context.colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// − n + control for share counts.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.name,
    required this.onChanged,
  });

  final int value;
  final String name;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Fewer shares for $name',
          icon: const Icon(Icons.remove_circle_outline_rounded),
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            semanticsLabel: '$name has $value shares',
            style: context.text.titleMedium?.tabular,
          ),
        ),
        IconButton(
          tooltip: 'More shares for $name',
          icon: const Icon(Icons.add_circle_outline_rounded),
          onPressed: value < 99 ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
