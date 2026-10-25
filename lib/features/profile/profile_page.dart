import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/services/theme_controller.dart';
import '../../core/motion/animated_widgets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/fin_card.dart';
import '../../shared/widgets/selection.dart';
import 'profile_controller.dart';

class ProfilePage extends GetView<ProfileController> {
  const ProfilePage({super.key});

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleReminders(BuildContext context, bool value) async {
    final result = await controller.setReminders(value);
    if (value && !result && context.mounted) {
      _snack(
        context,
        'Notifications are blocked. Allow them in system settings to get '
        'bill reminders.',
      );
    }
  }

  Future<void> _export(BuildContext context) async {
    final ok = await controller.exportCsv();
    if (!ok && context.mounted) _snack(context, 'Couldn\'t export. Try again.');
  }

  Future<void> _clear(BuildContext context) async {
    final confirmed = await AppBottomSheet.confirm(
      context,
      title: 'Delete all data?',
      message:
          'This permanently deletes every transaction, card, bill and EMI '
          'stored on this device. It cannot be undone. Export a CSV first if '
          'you want a copy.',
      confirmLabel: 'Delete everything',
      destructive: true,
      icon: Icons.delete_forever_rounded,
    );
    if (!confirmed) return;
    await controller.clearAll();
    if (context.mounted) _snack(context, 'All data deleted');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Get.find<ThemeController>();

    final sections = <Widget>[
      _Section(
        title: 'Appearance',
        child: FinCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Theme', style: context.text.titleSmall),
              const SizedBox(height: AppSpacing.md),
              Obx(
                () => GlassSegmented<AppThemePreference>(
                  segments: const [
                    (
                      AppThemePreference.system,
                      'System',
                      Icons.brightness_auto_rounded,
                    ),
                    (
                      AppThemePreference.light,
                      'Light',
                      Icons.light_mode_rounded,
                    ),
                    (AppThemePreference.dark, 'Dark', Icons.dark_mode_rounded),
                  ],
                  selected: theme.preference.value,
                  onChanged: theme.setPreference,
                ),
              ),
            ],
          ),
        ),
      ),
      _Section(
        title: 'Notifications',
        child: FinCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Obx(
            () => SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('Bill reminders'),
              subtitle: const Text(
                '3 days before and on the due date of unpaid card bills',
              ),
              value: controller.remindersEnabled.value,
              onChanged: (v) => _toggleReminders(context, v),
            ),
          ),
        ),
      ),
      _Section(
        title: 'Your data',
        child: FinCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.phone_android_rounded),
                title: Text('Stored on this device'),
                subtitle: Text(
                  'Nothing is uploaded. No bank or payment account is '
                  'connected; you enter transactions yourself.',
                ),
              ),
              Obx(
                () => ListTile(
                  leading: const Icon(Icons.ios_share_rounded),
                  title: const Text('Export transactions (CSV)'),
                  subtitle: const Text('Share a spreadsheet copy'),
                  enabled: !controller.busy.value,
                  onTap: () => _export(context),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: context.fin.failed,
                ),
                title: Text(
                  'Delete all data',
                  style: TextStyle(color: context.fin.failed),
                ),
                onTap: () => _clear(context),
              ),
            ],
          ),
        ),
      ),
      _Section(
        title: 'About',
        child: FinCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Get.toNamed<void>(AppRoutes.privacy),
              ),
              ListTile(
                leading: const Icon(Icons.slideshow_rounded),
                title: const Text('Show welcome tour'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Get.toNamed<void>(AppRoutes.onboarding),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Open-source licences'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'FinFlow',
                  applicationVersion: controller.version.value,
                ),
              ),
            ],
          ),
        ),
      ),
      Center(
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Obx(
            () => Text(
              controller.version.value.isEmpty
                  ? 'FinFlow'
                  : 'FinFlow ${controller.version.value}',
              style: context.text.bodySmall?.copyWith(
                color: context.fin.textMuted,
              ),
            ),
          ),
        ),
      ),
    ];

    return CustomScrollView(
      slivers: [
        const SliverAppBar.medium(pinned: true, title: Text('Profile')),
        SliverPadding(
          padding: pageInsets(context, maxWidth: 640).copyWith(
            bottom: AppSpacing.xxxl + MediaQuery.paddingOf(context).bottom,
          ),
          sliver: SliverList.list(
            addRepaintBoundaries: false,
            children: [
              for (var i = 0; i < sections.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.lg),
                FadeSlideIn(index: i, child: sections[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.sm,
          ),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: context.text.labelLarge?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
