import 'package:flutter/material.dart';

import '../../core/motion/animated_widgets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'app_button.dart';
import 'decor/glass_orb.dart';
import 'glass.dart';

/// Friendly placeholder for screens or sections with nothing to show.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = compact ? 72.0 : 112.0;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassOrb(icon: icon, size: size, float: true),
        SizedBox(height: compact ? AppSpacing.md : AppSpacing.xl),
        Text(
          title,
          textAlign: TextAlign.center,
          style: compact ? context.text.titleLarge : context.text.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: actionLabel!, onPressed: onAction),
        ],
      ],
    );

    // Compact states sit inside an existing card; full-page ones get their
    // own glass panel so the text stays readable over the background.
    return FadeSlideIn(
      child: compact
          ? Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl,
                vertical: AppSpacing.xl,
              ),
              child: content,
            )
          // Centred and sized to its content even when given the whole
          // remaining screen (e.g. inside SliverFillRemaining).
          : Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Glass(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.xxl,
                  ),
                  child: SizedBox(width: double.infinity, child: content),
                ),
              ),
            ),
    );
  }
}

/// Error placeholder with a retry action.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Try again',
    this.title = 'Something went wrong',
    this.icon = Icons.cloud_off_rounded,
  });

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: icon,
      title: title,
      message: message,
      actionLabel: retryLabel,
      onAction: onRetry,
    );
  }
}
