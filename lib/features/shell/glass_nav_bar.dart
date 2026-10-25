import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'app_tab.dart';

/// Floating, frosted-glass bottom navigation.
///
/// The selection pill moves like liquid: its leading edge leaves first and
/// its trailing edge catches up, so it stretches towards the new tab and
/// settles there. The selected icon pops with a small bounce.
class GlassNavBar extends StatefulWidget {
  const GlassNavBar({super.key, required this.current, required this.onSelect});

  final AppTab current;
  final ValueChanged<AppTab> onSelect;

  @override
  State<GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends State<GlassNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _move = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
    value: 1,
  );
  late int _from = widget.current.index;

  @override
  void didUpdateWidget(GlassNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current) {
      // Start from wherever the pill is right now (it may be mid-move).
      _from = oldWidget.current.index;
      _move.duration = AppMotion.of(context, const Duration(milliseconds: 560));
      _move.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _move.dispose();
    super.dispose();
  }

  void _tap(AppTab tab) {
    if (tab != widget.current) HapticFeedback.selectionClick();
    widget.onSelect(tab);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    const tabs = AppTab.values;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xs,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.xxl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.45 : 0.12),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.xxl),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: context.fin.glassTint,
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.xxl),
                  border: Border.all(color: context.fin.glassRim, width: 1),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth / tabs.length;
                    return Stack(
                      children: [
                        AnimatedBuilder(
                          animation: _move,
                          builder: (context, _) =>
                              _pill(itemWidth, widget.current.index, colors),
                        ),
                        Row(
                          children: [
                            for (final tab in tabs)
                              Expanded(
                                child: _NavItem(
                                  tab: tab,
                                  selected: tab == widget.current,
                                  onTap: () => _tap(tab),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(double itemWidth, int to, ColorScheme colors) {
    const inset = 6.0;
    final t = _move.value;
    final forward = to >= _from;
    // The edge facing the destination moves first; the other follows.
    final lead = AppMotion.silk.transform(const Interval(0, 0.75).transform(t));
    final trail = AppMotion.settle.transform(
      const Interval(0.12, 1).transform(t),
    );
    final fromL = _from * itemWidth + inset;
    final fromR = (_from + 1) * itemWidth - inset;
    final toL = to * itemWidth + inset;
    final toR = (to + 1) * itemWidth - inset;
    final left = lerpDouble(fromL, toL, forward ? trail : lead)!;
    final right = lerpDouble(fromR, toR, forward ? lead : trail)!;

    final fin = context.fin;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final width = (right - left).clamp(0.0, double.infinity);
    return Positioned(
      left: left,
      width: width,
      top: inset,
      bottom: inset,
      child: Stack(
        children: [
          // Glass bubble behind the active item.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.xl),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: dark ? 0.2 : 0.85),
                    Colors.white.withValues(alpha: dark ? 0.06 : 0.45),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: dark ? 0.3 : 0.95),
                ),
                boxShadow: [
                  BoxShadow(
                    color: fin.accent.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final fg = selected ? fin.accent : context.colors.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  key: ValueKey(selected),
                  tween: Tween(begin: selected ? 0.7 : 1, end: 1),
                  duration: AppMotion.of(
                    context,
                    const Duration(milliseconds: 520),
                  ),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: selected
                      ? ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (rect) =>
                              fin.accentGradient.createShader(rect),
                          child: Icon(tab.selectedIcon, size: 24),
                        )
                      : Icon(tab.icon, size: 24, color: fg),
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: AppMotion.of(context, AppMotion.medium),
                  style: context.text.labelSmall!.copyWith(
                    fontSize: 11.5,
                    letterSpacing: 0.1,
                    color: fg,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(tab.label, maxLines: 1),
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
