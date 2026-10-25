import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'decor/ambient_background.dart';

import '../../core/motion/animated_widgets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Frosted glass surface.
///
/// Blurs whatever is behind it, lays a tint over the blur (brighter at the
/// top, like light falling on a pane), and draws a rim highlight that is
/// strongest at the top-left edge.
///
/// Inside a still [AmbientBackground] the blur comes from the background's
/// cached, pre-blurred image (see [BackdropSlice]); elsewhere each panel
/// blurs live. (Sharing one live pass via `BackdropGroup` was tried and
/// dropped: on Android it stopped the blur from seeing the background.)
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.borderRadius = AppRadii.card,
    this.blur = 16,
    this.tint,
    this.shadow = true,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double blur;

  /// Optional colour mixed into the glass (e.g. a status colour).
  final Color? tint;
  final bool shadow;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final reveal = RevealScope.claim(context);
    if (reveal == null) return _panel(context, 1);
    // Inside an entrance animation: frost in (blur, tint, rim and content
    // grow together) instead of fading through an opacity layer.
    return AnimatedBuilder(
      animation: reveal,
      builder: (context, _) => _panel(context, reveal.value.clamp(0.0, 1.0)),
    );
  }

  Widget _panel(BuildContext context, double t) {
    final fin = context.fin;
    final dark = Theme.of(context).brightness == Brightness.dark;
    Color fade(Color c) => c.withValues(alpha: c.a * t);
    final top = tint == null
        ? fin.glassTint[0]
        : Color.lerp(fin.glassTint[0], tint, 0.22)!;
    final bottom = tint == null
        ? fin.glassTint[1]
        : Color.lerp(fin.glassTint[1], tint, 0.16)!;
    final sigma = blur * t;

    final surface = CustomPaint(
      foregroundPainter: _RimPainter(
        radius: borderRadius,
        rim: fade(fin.glassRim),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [fade(top), fade(bottom)],
          ),
        ),
        child: Padding(
          padding: padding,
          // Content alone may use an opacity layer: it has no blur.
          child: Opacity(opacity: t, child: child),
        ),
      ),
    );

    // Over a still background, draw the matching slice of its pre-blurred
    // copy: identical to a live blur of the background, at a fraction of
    // the cost. Otherwise blur live.
    final scope = BackdropScope.of(context);
    final blurred = scope?.blurred;
    Widget panel = ClipRRect(
      borderRadius: borderRadius,
      child: blurred != null
          // passthrough: the surface keeps the panel's own constraints, so
          // the glass always fills the panel (not just its content).
          ? Stack(
              fit: StackFit.passthrough,
              children: [
                Positioned.fill(
                  child: BackdropSlice(
                    image: blurred,
                    hostKey: scope!.hostKey,
                    opacity: t,
                  ),
                ),
                surface,
              ],
            )
          : BackdropFilter(
              enabled: sigma > 0.05,
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: surface,
            ),
    );

    if (shadow) {
      panel = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: fade(
                dark
                    ? Colors.black.withValues(alpha: 0.35)
                    : const Color(0xFF3B3F8F).withValues(alpha: 0.12),
              ),
              blurRadius: 20,
              spreadRadius: -8,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: panel,
      );
    }
    return panel;
  }
}

class _RimPainter extends CustomPainter {
  const _RimPainter({required this.radius, required this.rim});

  final BorderRadius radius;
  final Color rim;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect).deflate(0.6);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            rim,
            rim.withValues(alpha: rim.a * 0.25),
            rim.withValues(alpha: rim.a * 0.08),
            rim.withValues(alpha: rim.a * 0.45),
          ],
          stops: const [0, 0.35, 0.7, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RimPainter old) => old.rim != rim || old.radius != radius;
}
