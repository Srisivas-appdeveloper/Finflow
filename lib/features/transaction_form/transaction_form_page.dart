import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/config/app_environment.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../domain/entities/transaction.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_inputs.dart';
import '../../shared/widgets/category_style.dart';
import '../../shared/widgets/decor/ambient_background.dart';
import '../../shared/widgets/fin_card.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/loading.dart';
import '../../shared/widgets/selection.dart';
import '../split/split_actions.dart';
import '../split/widgets/split_widgets.dart';
import 'transaction_form_controller.dart';

class TransactionFormPage extends GetView<TransactionFormController> {
  const TransactionFormPage({super.key});

  static const _methodIcons = {
    PaymentMethod.upi: Icons.qr_code_2_rounded,
    PaymentMethod.card: Icons.credit_card_rounded,
    PaymentMethod.bankTransfer: Icons.account_balance_rounded,
    PaymentMethod.cash: Icons.payments_outlined,
    PaymentMethod.wallet: Icons.account_balance_wallet_outlined,
    PaymentMethod.paidByOther: Icons.group_outlined,
  };

  Future<void> _save(BuildContext context) async {
    FocusScope.of(context).unfocus();
    try {
      final split = controller.splitAfterSave.value && controller.canSplit;
      if (split && !controller.validate()) return;
      // Choose the group first, so cancelling leaves nothing half done.
      final group = split ? await SplitActions().pickGroup(context) : null;
      if (split && group == null) return;
      final saved = await controller.save();
      if (saved == null) return;
      if (group != null) {
        Get.offNamed<void>(
          AppRoutes.splitExpenseOf(group.id, transactionId: saved.id),
        );
        return;
      }
      Get.back<Transaction>(result: saved);
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
          controller.isEditing ? 'Edit transaction' : 'Add transaction',
        ),
        leading: const CloseButton(),
      ),
      body: AmbientBackground(
        objects: false,
        child: Obx(() {
          if (controller.loading.value) return const LoadingView();
          final income =
              controller.direction.value == TransactionDirection.credit;
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
                          if (!controller.isLockedType) ...[
                            GlassSegmented<TransactionDirection>(
                              segments: const [
                                (
                                  TransactionDirection.debit,
                                  'Spending',
                                  Icons.north_east_rounded,
                                ),
                                (
                                  TransactionDirection.credit,
                                  'Income',
                                  Icons.south_west_rounded,
                                ),
                              ],
                              selected: controller.direction.value,
                              onChanged: controller.setDirection,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          AmountField(
                            controller: controller.amount,
                            currencySymbol: symbol,
                            errorText: controller.amountError.value,
                            onChanged: controller.onAmountChanged,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: controller.title,
                            label: income ? 'Received from' : 'Paid to',
                            hint: income
                                ? 'e.g. Employer'
                                : 'e.g. Grocery store',
                            prefixIcon: Icons.storefront_outlined,
                            errorText: controller.titleError.value,
                            onChanged: controller.onTitleChanged,
                            textInputAction: TextInputAction.next,
                          ),
                        ],
                      ),
                    ),
                    if (controller.canSplit)
                      FormSection(
                        label: 'Split',
                        child: _SplitToggle(
                          value: controller.splitAfterSave.value,
                          onChanged: (v) => controller.splitAfterSave.value = v,
                        ),
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
                    FormSection(
                      label: income ? 'Received via' : 'Paid with',
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
                      label: 'Status',
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final s in TransactionStatus.values)
                            GlassChip(
                              label: s.label,
                              dotColor: switch (s) {
                                TransactionStatus.completed =>
                                  context.fin.income,
                                TransactionStatus.pending =>
                                  context.fin.pending,
                                TransactionStatus.failed => context.fin.failed,
                              },
                              selected: controller.status.value == s,
                              onTap: () => controller.status.value = s,
                            ),
                        ],
                      ),
                    ),
                    FormSection(
                      label: 'Note',
                      child: AppTextField(
                        controller: controller.note,
                        hint: 'Optional',
                        maxLines: 3,
                        prefixIcon: Icons.sticky_note_2_outlined,
                      ),
                    ),
                  ],
                ),
              ),
              _SaveBar(
                label: controller.isEditing
                    ? 'Save changes'
                    : controller.splitAfterSave.value && controller.canSplit
                    ? 'Next: split it'
                    : 'Add transaction',
                saving: controller.saving.value,
                onPressed: () => _save(context),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// Switch to split the new spend with a group after saving.
class _SplitToggle extends StatelessWidget {
  const _SplitToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return FinCard(
      onTap: () => onChanged(!value),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: MergeSemantics(
        child: Row(
          children: [
            const GroupOrb(size: 40),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Split with roommates or friends',
                    style: context.text.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value
                        ? 'Next, choose who shares it'
                        : 'Only your share will count as your spending',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.label,
    required this.saving,
    required this.onPressed,
  });

  final String label;
  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: pageInsets(
          context,
          maxWidth: 640,
        ).copyWith(top: AppSpacing.sm, bottom: AppSpacing.md),
        child: AppButton(
          label: label,
          icon: Icons.check_rounded,
          expand: true,
          loading: saving,
          onPressed: onPressed,
        ),
      ),
    );
  }
}
