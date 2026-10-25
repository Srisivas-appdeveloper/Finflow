import 'package:flutter/material.dart';

import '../../core/motion/animated_widgets.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

enum AppButtonVariant { primary, tonal, outline, text, destructive }

enum AppButtonSize { regular, small }

/// The app's single button component.
///
/// While [loading] is true the button keeps its size, shows a spinner and
/// ignores taps, so a form can't be submitted twice.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.regular,
    this.icon,
    this.loading = false,
    this.expand = false,
  });

  const AppButton.tonal({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.regular,
    this.icon,
    this.loading = false,
    this.expand = false,
  }) : variant = AppButtonVariant.tonal;

  const AppButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.regular,
    this.icon,
    this.loading = false,
    this.expand = false,
  }) : variant = AppButtonVariant.outline;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final small = size == AppButtonSize.small;
    final minSize = Size(small ? 48 : 64, small ? 40 : 52);
    final padding = EdgeInsets.symmetric(
      horizontal: small ? AppSpacing.md + 2 : AppSpacing.xl,
    );
    final textStyle = small
        ? context.text.labelMedium
        : context.text.labelLarge;
    final callback = loading ? () {} : onPressed;

    final style = switch (variant) {
      // Transparent fill: the gradient is painted underneath.
      AppButtonVariant.primary => FilledButton.styleFrom(
        minimumSize: minSize,
        padding: padding,
        textStyle: textStyle,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        shadowColor: Colors.transparent,
        disabledBackgroundColor: colors.onSurface.withValues(alpha: 0.12),
      ),
      AppButtonVariant.tonal => FilledButton.styleFrom(
        minimumSize: minSize,
        padding: padding,
        textStyle: textStyle,
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
      ),
      AppButtonVariant.destructive => FilledButton.styleFrom(
        minimumSize: minSize,
        padding: padding,
        textStyle: textStyle,
        backgroundColor: colors.error,
        foregroundColor: colors.onError,
      ),
      AppButtonVariant.outline => OutlinedButton.styleFrom(
        minimumSize: minSize,
        padding: padding,
        textStyle: textStyle,
      ),
      AppButtonVariant.text => TextButton.styleFrom(
        minimumSize: minSize,
        padding: padding,
        textStyle: textStyle,
      ),
    };

    final content = AnimatedSwitcher(
      duration: AppMotion.of(context, AppMotion.short),
      child: loading
          ? SizedBox.square(
              key: const ValueKey('loading'),
              dimension: small ? 16 : 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: variant == AppButtonVariant.primary
                    ? Colors.white
                    : null,
              ),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: small ? 18 : 20),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );

    Widget button = switch (variant) {
      AppButtonVariant.outline => OutlinedButton(
        onPressed: callback,
        style: style,
        child: content,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: callback,
        style: style,
        child: content,
      ),
      _ => FilledButton(onPressed: callback, style: style, child: content),
    };

    // Primary: accent gradient with a soft glow while enabled.
    if (variant == AppButtonVariant.primary && onPressed != null) {
      final fin = context.fin;
      button = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          gradient: fin.accentGradient,
          boxShadow: [
            BoxShadow(
              color: fin.accent.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: button,
      );
    }

    return Semantics(
      label: loading ? '$label, loading' : null,
      child: PressableScale(
        enabled: onPressed != null && !loading,
        child: expand
            ? SizedBox(width: double.infinity, child: button)
            : button,
      ),
    );
  }
}
