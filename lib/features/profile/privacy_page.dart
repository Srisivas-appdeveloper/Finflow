import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../shared/widgets/decor/ambient_background.dart';
import '../../shared/widgets/fin_card.dart';

/// In-app summary of how FinFlow handles data. Must stay consistent with
/// docs/play-store/privacy-policy.md and the Play Data Safety answers.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  static const _points = [
    (
      Icons.phone_android_rounded,
      'Your data stays on this device',
      'Transactions, cards, bills, EMIs and split groups (including the names '
          'you type for people) are stored only in the app\'s private storage '
          'on this phone. FinFlow has no servers and no account system.',
    ),
    (
      Icons.cloud_off_rounded,
      'Nothing is uploaded',
      'FinFlow does not connect to the internet, collect analytics, show ads '
          'or share data with anyone. It does not read SMS, emails or '
          'notifications.',
    ),
    (
      Icons.account_balance_outlined,
      'No bank connections',
      'FinFlow does not connect to banks or card issuers. Amounts and due '
          'dates come only from what you type in.',
    ),
    (
      Icons.backup_outlined,
      'Backups are up to you',
      'Android cloud backup is turned off for FinFlow so your financial data '
          'is not copied to the cloud. Use Export (CSV) to keep your own copy. '
          'Uninstalling the app deletes its data.',
    ),
    (
      Icons.notifications_none_rounded,
      'Notifications',
      'If you turn on bill reminders, they are scheduled on the device by '
          'Android. Their content never leaves the phone.',
    ),
    (
      Icons.delete_outline_rounded,
      'You are in control',
      'Delete all data at any time from Profile > Your data.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Privacy')),
      body: AmbientBackground(
        objects: false,
        child: ListView(
          addRepaintBoundaries: false,
          padding: pageInsets(context, maxWidth: 640).copyWith(
            top: MediaQuery.paddingOf(context).top + kToolbarHeight,
            bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xxxl,
          ),
          children: [
            for (final (icon, title, body) in _points) ...[
              FinCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: context.fin.accent),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: context.text.titleSmall),
                          const SizedBox(height: AppSpacing.xs),
                          Text(body, style: context.text.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}
