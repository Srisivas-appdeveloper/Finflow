import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/motion/animated_widgets.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'app_button.dart';
import 'selection.dart';

/// Modal bottom sheets with the app's own motion:
/// * the screen behind blurs and dims progressively,
/// * the sheet rises on a spring and settles with a slight overshoot,
/// * its header, body and actions reveal one after another,
/// * it can be dragged down to dismiss and follows the finger exactly.
///
/// Keyboard-aware, capped at 90% height and width-limited on tablets.
abstract final class AppBottomSheet {
  /// Presents [builder]'s widget (normally an [AppSheet]) as a modal sheet.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
  }) {
    final navigator = Navigator.of(context);
    return navigator.push(
      _AppSheetRoute<T>(
        builder: builder,
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
        themes: InheritedTheme.capture(from: context, to: navigator.context),
      ),
    );
  }

  /// Asks the user to confirm an action. Resolves `true` only when the
  /// confirm button is pressed.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
    IconData icon = Icons.help_outline_rounded,
  }) async {
    final result = await show<bool>(
      context,
      builder: (context) => AppSheet(
        title: title,
        icon: icon,
        destructive: destructive,
        body: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text(message, style: context.text.bodyLarge),
        ),
        actions: Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.text,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(
                label: confirmLabel,
                variant: destructive
                    ? AppButtonVariant.destructive
                    : AppButtonVariant.primary,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  /// A menu of commands (e.g. Pay, Edit, Delete). Resolves with the chosen
  /// action's value, or `null` if dismissed.
  static Future<T?> actions<T>(
    BuildContext context, {
    required String title,
    required List<SheetAction<T>> actions,
    String? subtitle,
    IconData icon = Icons.more_horiz_rounded,
  }) {
    return show<T>(
      context,
      builder: (context) => AppSheet(
        title: title,
        subtitle: subtitle,
        icon: icon,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < actions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: FadeSlideIn(
                  index: i,
                  offset: const Offset(0, 12),
                  child: _ActionRow(
                    action: actions[i],
                    onTap: () => Navigator.of(context).pop(actions[i].value),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// A single-choice list. Resolves with the chosen value, or `null` if
  /// dismissed.
  static Future<T?> choose<T>(
    BuildContext context, {
    required String title,
    required List<T> options,
    required String Function(T) labelOf,
    Widget Function(T)? leadingOf,
    T? selected,
    String? subtitle,
    IconData icon = Icons.tune_rounded,
  }) {
    return show<T>(
      context,
      builder: (context) => AppSheet(
        title: title,
        subtitle: subtitle,
        icon: icon,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: FadeSlideIn(
                  index: i,
                  offset: const Offset(0, 12),
                  child: ChoiceRow(
                    label: labelOf(options[i]),
                    leading: leadingOf?.call(options[i]),
                    selected: options[i] == selected,
                    onTap: () => Navigator.of(context).pop(options[i]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AppSheetRoute<T> extends PopupRoute<T> {
  _AppSheetRoute({
    required this.builder,
    required this.barrierLabel,
    required this.themes,
  });

  final WidgetBuilder builder;
  final CapturedThemes themes;

  @override
  final String? barrierLabel;

  /// The scrim is painted by the route itself (blur + tint), so the modal
  /// barrier only handles taps.
  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 620);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);

  /// While the user drags (and until the resulting animation finishes), the
  /// sheet position is linear in the controller value so it tracks the
  /// finger without jumps.
  bool _direct = false;

  void _dragBy(double fraction) {
    _direct = true;
    controller!.value = (controller!.value - fraction).clamp(0.0, 1.0);
  }

  void _dragEnd(double velocityFraction, NavigatorState navigator) {
    final c = controller!;
    if (velocityFraction > 1.2 || (c.value < 0.65 && velocityFraction > -0.5)) {
      HapticFeedback.lightImpact();
      navigator.pop();
    } else {
      c.animateTo(
        1,
        duration: const Duration(milliseconds: 380),
        curve: AppMotion.silk,
      );
    }
  }

  @override
  AnimationController createAnimationController() {
    final c = super.createAnimationController();
    c.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _direct = false;
      }
    });
    return c;
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => themes.wrap(Builder(builder: builder));

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _SheetFrame(route: this, animation: animation, child: child);
  }
}

class _SheetFrame extends StatefulWidget {
  const _SheetFrame({
    required this.route,
    required this.animation,
    required this.child,
  });

  final _AppSheetRoute<dynamic> route;
  final Animation<double> animation;
  final Widget child;

  @override
  State<_SheetFrame> createState() => _SheetFrameState();
}

class _SheetFrameState extends State<_SheetFrame> {
  final _sheetKey = GlobalKey();

  double get _sheetHeight =>
      (_sheetKey.currentContext?.size?.height ?? 400).clamp(1, double.infinity);

  /// Position of the sheet: 0 hidden, 1 fully open (may briefly exceed 1).
  double _position() {
    final a = widget.animation;
    final t = a.value;
    if (AppMotion.reduced(context)) return t > 0 ? 1 : 0;
    if (widget.route._direct) return t;
    return a.status == AnimationStatus.reverse
        ? Curves.easeInCubic.transform(t)
        : AppMotion.spring.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final maxHeight = (media.size.height - media.padding.top - 24) * 0.98;
    final sheetColor = colors.surface;

    return AnimatedBuilder(
      animation: widget.animation,
      child: widget.child,
      builder: (context, child) {
        final t = widget.animation.value.clamp(0.0, 1.0);
        final pos = _position();
        final reveal = pos.clamp(0.0, 1.0);

        return Stack(
          children: [
            // Progressive blur + tint over the page behind. Taps pass
            // through to the route's modal barrier (dismiss).
            Positioned.fill(
              child: IgnorePointer(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5 * t, sigmaY: 5 * t),
                  child: ColoredBox(
                    color: Colors.black.withValues(
                      alpha: (dark ? 0.45 : 0.28) * t,
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 640,
                  maxHeight: maxHeight,
                ),
                child: FractionalTranslation(
                  translation: Offset(0, 1 - pos),
                  child: Transform.scale(
                    scale: 0.94 + 0.06 * reveal,
                    alignment: Alignment.bottomCenter,
                    child: GestureDetector(
                      onVerticalDragUpdate: (d) =>
                          widget.route._dragBy(d.primaryDelta! / _sheetHeight),
                      onVerticalDragEnd: (d) => widget.route._dragEnd(
                        d.primaryVelocity! / _sheetHeight,
                        Navigator.of(context),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Extends the sheet below the screen edge so the
                          // spring overshoot never reveals a gap.
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: -80,
                            height: 120,
                            child: ColoredBox(
                              color: sheetColor.withValues(
                                alpha: dark ? 0.86 : 0.9,
                              ),
                            ),
                          ),
                          // Frosted glass sheet: blurs the (already
                          // dimmed) page behind and lets its colour through.
                          ClipRRect(
                            key: _sheetKey,
                            borderRadius: AppRadii.sheet,
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                              child: Material(
                                type: MaterialType.transparency,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: AppRadii.sheet,
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        sheetColor.withValues(
                                          alpha: dark ? 0.72 : 0.8,
                                        ),
                                        sheetColor.withValues(
                                          alpha: dark ? 0.86 : 0.9,
                                        ),
                                      ],
                                    ),
                                    border: Border(
                                      top: BorderSide(
                                        color: context.fin.glassRim,
                                        width: 1.2,
                                      ),
                                    ),
                                  ),
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Layout for sheet content: a glowing handle, a header with an icon orb,
/// title, subtitle and glass close button, a scrollable [body] and optional
/// [actions] pinned to the bottom. Each part reveals slightly after the
/// sheet starts rising.
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.icon,
    this.destructive = false,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? actions;

  /// Shown in a gradient orb beside the title.
  final IconData? icon;

  /// Shows the header orb in the warning colour (for delete confirmations).
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final animation =
        ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;

    return Stack(
      children: [
        // Soft accent glow behind the header.
        Positioned(
          top: -120,
          left: -40,
          right: -40,
          height: 260,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    fin.accent.withValues(alpha: 0.28),
                    fin.accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: AppSpacing.md),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: fin.accentGradient,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    boxShadow: [
                      BoxShadow(
                        color: fin.accent.withValues(alpha: 0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
              _Reveal(
                animation: animation,
                start: 0.15,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      if (icon != null) ...[
                        _HeaderOrb(icon: icon!, destructive: destructive),
                        const SizedBox(width: AppSpacing.md),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                title,
                                style: context.text.headlineSmall!.copyWith(
                                  fontSize: 22,
                                ),
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(subtitle!, style: context.text.bodySmall),
                            ],
                          ],
                        ),
                      ),
                      _CloseButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                ),
              ),
              Flexible(
                child: _Reveal(
                  animation: animation,
                  start: 0.25,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xs,
                      AppSpacing.xl,
                      AppSpacing.lg,
                    ),
                    child: body,
                  ),
                ),
              ),
              if (actions != null)
                _Reveal(
                  animation: animation,
                  start: 0.35,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: fin.hairline)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl,
                          AppSpacing.md,
                          AppSpacing.xl,
                          AppSpacing.md,
                        ),
                        child: actions,
                      ),
                    ),
                  ),
                )
              else
                SizedBox(height: MediaQuery.paddingOf(context).bottom),
            ],
          ),
        ),
      ],
    );
  }
}

/// Section title inside a sheet: small tracked label in the accent colour.
class SheetSection extends StatelessWidget {
  const SheetSection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: context.text.eyebrow.copyWith(color: context.fin.accent),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _HeaderOrb extends StatelessWidget {
  const _HeaderOrb({required this.icon, this.destructive = false});

  final IconData icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final glow = destructive ? fin.failed : fin.accent;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: destructive ? fin.failed : null,
        gradient: destructive ? null : fin.accentGradient,
        border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return Tooltip(
      message: 'Close',
      child: Semantics(
        button: true,
        label: 'Close',
        excludeSemantics: true,
        child: PressableScale(
          scale: 0.9,
          child: GestureDetector(
            onTap: onPressed,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: fin.glassTint,
                ),
                border: Border.all(color: fin.glassRim),
              ),
              child: Icon(
                Icons.close_rounded,
                size: 20,
                color: context.colors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fades and lifts [child] in during the forward part of [animation] that
/// starts at [start]. On dismissal it stays visible so content leaves with
/// the sheet.
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.animation,
    required this.start,
    required this.child,
  });

  final Animation<double> animation;
  final double start;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        // Same widget structure in every state so the content's own state
        // (scroll position, focus) is never rebuilt.
        final entering =
            animation.status == AnimationStatus.forward &&
            !AppMotion.reduced(context);
        final t = entering
            ? Curves.easeOutCubic.transform(
                Interval(
                  start,
                  (start + 0.55).clamp(0, 1),
                ).transform(animation.value),
              )
            : 1.0;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}

/// One command in [AppBottomSheet.actions].
class SheetAction<T> {
  const SheetAction({
    required this.value,
    required this.label,
    required this.icon,
    this.destructive = false,
  });

  final T value;
  final String label;
  final IconData icon;
  final bool destructive;
}

class _ActionRow<T> extends StatelessWidget {
  const _ActionRow({required this.action, required this.onTap});

  final SheetAction<T> action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final color = action.destructive ? fin.failed : fin.accent;
    return Semantics(
      button: true,
      label: action.label,
      excludeSemantics: true,
      child: PressableScale(
        scale: 0.97,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: AppRadii.control,
            onTap: onTap,
            child: Ink(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                borderRadius: AppRadii.control,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: fin.glassTint,
                ),
                border: Border.all(color: fin.glassRim),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.14),
                    ),
                    child: Icon(action.icon, size: 19, color: color),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      action.label,
                      style: context.text.titleSmall?.copyWith(
                        color: action.destructive ? fin.failed : null,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
