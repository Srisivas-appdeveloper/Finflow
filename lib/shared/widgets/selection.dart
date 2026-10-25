import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/motion/animated_widgets.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Decoration shared by unselected selection controls: a light glass fill
/// with a rim.
BoxDecoration _glassFill(BuildContext context, BorderRadius radius) {
  final fin = context.fin;
  return BoxDecoration(
    borderRadius: radius,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: fin.glassTint,
    ),
    border: Border.all(color: fin.glassRim, width: 1),
  );
}

/// Selected state: the accent gradient with a soft coloured glow.
BoxDecoration _accentFill(BuildContext context, BorderRadius radius) {
  final fin = context.fin;
  return BoxDecoration(
    borderRadius: radius,
    gradient: fin.accentGradient,
    border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
    boxShadow: [
      BoxShadow(
        color: fin.accent.withValues(alpha: 0.4),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

/// Selectable glass pill. Selection fills it with the accent gradient and
/// pops in a check mark.
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.iconColor,
    this.dotColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? iconColor;

  /// Small status dot shown before the label.
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const radius = BorderRadius.all(Radius.circular(AppRadii.pill));
    final fg = selected ? Colors.white : colors.onSurface;
    final duration = AppMotion.of(context, const Duration(milliseconds: 280));

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: PressableScale(
        scale: 0.94,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: duration,
            curve: AppMotion.decelerate,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: selected
                ? _accentFill(context, radius)
                : _glassFill(context, radius),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dotColor != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: selected ? Colors.white : (iconColor ?? fg),
                  ),
                  const SizedBox(width: 6),
                ],
                // Long labels (such as people's names) shorten instead of
                // overflowing a narrow screen.
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelLarge!.copyWith(
                      fontSize: 13.5,
                      color: fg,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: duration,
                  curve: AppMotion.settle,
                  child: selected
                      ? const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Larger selectable tile with an icon above a label, for small sets of
/// mutually exclusive options (e.g. sort order).
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final colors = context.colors;
    const radius = AppRadii.control;
    final duration = AppMotion.of(context, const Duration(milliseconds: 280));

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: PressableScale(
        scale: 0.95,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: duration,
            curve: AppMotion.decelerate,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: selected
                ? _accentFill(context, radius)
                : _glassFill(context, radius),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: duration,
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.22)
                        : fin.accent.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: selected ? Colors.white : fin.accent,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    style: context.text.labelLarge!.copyWith(
                      fontSize: 13.5,
                      color: selected ? Colors.white : colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Single-choice row for lists in sheets: glass row, gradient check when
/// selected.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    const radius = AppRadii.control;
    final duration = AppMotion.of(context, const Duration(milliseconds: 260));

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: PressableScale(
        scale: 0.97,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: duration,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: _glassFill(context, radius).copyWith(
              border: Border.all(
                color: selected ? fin.accent : fin.glassRim,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                ?leading,
                if (leading != null) const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(label, style: context.text.titleSmall)),
                AnimatedContainer(
                  duration: duration,
                  curve: AppMotion.settle,
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: selected ? fin.accentGradient : null,
                    border: selected
                        ? null
                        : Border.all(color: fin.textMuted, width: 1.4),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Round glass icon button. [active] fills it with the accent gradient.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.active = false,
    this.size = 46,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size / 2);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: PressableScale(
          scale: 0.9,
          child: GestureDetector(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: AppMotion.of(context, AppMotion.medium),
              width: size,
              height: size,
              decoration: active
                  ? _accentFill(context, radius)
                  : _glassFill(context, radius),
              child: Icon(
                icon,
                size: size * 0.45,
                color: active ? Colors.white : context.colors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass segmented control: equal-width segments with a gradient pill that
/// slides (with a slight settle) to the selected segment.
class GlassSegmented<T> extends StatelessWidget {
  const GlassSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  /// Value, label and optional icon for each segment, in order.
  final List<(T, String, IconData?)> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final index = segments.indexWhere((s) => s.$1 == selected);
    const radius = BorderRadius.all(Radius.circular(AppRadii.pill));
    final duration = AppMotion.of(context, const Duration(milliseconds: 420));

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: _glassFill(context, radius),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / segments.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: duration,
                curve: AppMotion.settle,
                left: w * index,
                width: w,
                top: 0,
                bottom: 0,
                child: DecoratedBox(decoration: _accentFill(context, radius)),
              ),
              Row(
                children: [
                  for (final (value, label, icon) in segments)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: value == selected,
                        label: label,
                        excludeSemantics: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (value == selected) return;
                            HapticFeedback.selectionClick();
                            onChanged(value);
                          },
                          child: _Segment(
                            label: label,
                            icon: icon,
                            selected: value == selected,
                            duration: duration,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.duration,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : context.colors.onSurfaceVariant;
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 5),
              ],
              AnimatedDefaultTextStyle(
                duration: duration,
                style: context.text.labelLarge!.copyWith(
                  fontSize: 13.5,
                  color: fg,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
