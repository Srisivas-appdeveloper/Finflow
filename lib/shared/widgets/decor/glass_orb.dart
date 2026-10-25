import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_colors.dart';

/// A glowing glass sphere filled with the accent gradient, showing an
/// [icon] or a [monogram]. With [float] it bobs gently. Used for empty
/// states and the profile mark.
class GlassOrb extends StatefulWidget {
  const GlassOrb({
    super.key,
    this.icon,
    this.monogram,
    this.size = 96,
    this.float = false,
  }) : assert(icon != null || monogram != null);

  final IconData? icon;
  final String? monogram;
  final double size;
  final bool float;

  @override
  State<GlassOrb> createState() => _GlassOrbState();
}

class _GlassOrbState extends State<GlassOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.float && AppMotion.ambientIn(context)) {
      if (!_bob.isAnimating) _bob.repeat();
    } else {
      _bob.stop();
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final s = widget.size;
    final orb = SizedBox.square(
      dimension: s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: fin.accentGradient,
              boxShadow: [
                BoxShadow(
                  color: fin.accent.withValues(alpha: 0.45),
                  blurRadius: s * 0.45,
                  offset: Offset(0, s * 0.16),
                ),
              ],
            ),
            child: const SizedBox.expand(),
          ),
          // Glass shell: lighter top, rim light.
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.45),
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: const [0, 0.55],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: s > 60 ? 1.4 : 1,
              ),
            ),
            child: const SizedBox.expand(),
          ),
          if (widget.icon != null)
            Icon(widget.icon, size: s * 0.42, color: Colors.white)
          else
            Text(
              widget.monogram!,
              style: context.text.titleLarge!.copyWith(
                color: Colors.white,
                fontSize: s * 0.42,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
    if (!widget.float) return orb;
    return AnimatedBuilder(
      animation: _bob,
      child: orb,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, math.sin(_bob.value * 2 * math.pi) * s * 0.05),
        child: child,
      ),
    );
  }
}
