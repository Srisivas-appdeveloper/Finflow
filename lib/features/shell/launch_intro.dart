import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/decor/ambient_background.dart';
import '../../shared/widgets/decor/gold_coin.dart';

/// Cold-start brand moment (about 3 s), played once per app process:
/// 1. a gold rupee coin spins in from the distance and settles, with a
///    rotating light burst and an expanding ring of particles,
/// 2. the coin lifts as the gradient "FinFlow" wordmark unveils beneath it,
///    a hairline draws out and the tagline rises,
/// 3. the whole scene zooms gently towards the viewer and dissolves.
///
/// [onReveal] fires as the dissolve begins (start content then); [onDone]
/// when the overlay is gone.
class LaunchIntro extends StatefulWidget {
  const LaunchIntro({super.key, required this.onReveal, required this.onDone});

  final VoidCallback onReveal;
  final VoidCallback onDone;

  /// Whether the intro has already played in this process.
  static bool played = false;

  @override
  State<LaunchIntro> createState() => _LaunchIntroState();
}

class _LaunchIntroState extends State<LaunchIntro>
    with SingleTickerProviderStateMixin {
  static const _revealAt = 0.74;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (!_revealed && _c.value >= _revealAt) {
        _revealed = true;
        widget.onReveal();
      }
    });
    _c.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _at(double begin, double end, [Curve curve = AppMotion.silk]) =>
      curve.transform(Interval(begin, end).transform(_c.value));

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final size = MediaQuery.sizeOf(context);
          final coinIn = _at(0, 0.32);
          final coinSpin = (1 - _at(0, 0.4)) * math.pi * 8;
          final lift = _at(0.36, 0.6);
          final burst =
              _at(0.12, 0.45, Curves.easeOut) *
              (1 - _at(0.5, 0.72, Curves.easeIn));
          final ring = _at(0.22, 0.6, Curves.easeOutCubic);
          final unveil = _at(0.38, 0.62);
          final line = _at(0.5, 0.7);
          final tagline = _at(0.55, 0.72, Curves.easeOut);
          final exit = _at(_revealAt, 1, Curves.easeInOutCubic);

          final coinSize = 120.0 * (0.15 + 0.85 * coinIn) * (1 - 0.35 * lift);
          final center = Offset(
            size.width / 2,
            size.height * (0.46 - 0.12 * lift),
          );

          final wordmark = ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (rect) => LinearGradient(
              colors: [fin.accentBright, fin.accent, AppPalette.cyan],
              stops: [0, 0.5 + 0.4 * (1 - unveil), 1],
            ).createShader(rect),
            child: Text(
              'FinFlow',
              style: context.text.greeting.copyWith(
                fontSize: 52,
                letterSpacing: 12 * (1 - unveil) - 1,
              ),
            ),
          );

          return Opacity(
            opacity: 1 - exit,
            child: Transform.scale(
              scale: 1 + 0.15 * exit,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const AmbientBackground(objects: false),
                  // Rotating light burst behind the coin.
                  CustomPaint(
                    painter: _BurstPainter(
                      center: center,
                      strength: burst,
                      rotation: _c.value * math.pi,
                      color: AppPalette.amber,
                    ),
                  ),
                  // Expanding particle ring.
                  CustomPaint(
                    painter: _RingPainter(
                      center: center,
                      progress: ring,
                      colors: [fin.accent, AppPalette.cyan, AppPalette.amber],
                    ),
                  ),
                  Positioned(
                    left: center.dx - coinSize / 2,
                    top: center.dy - coinSize / 2,
                    child: Opacity(
                      opacity: coinIn.clamp(0.0, 1.0),
                      child: GoldCoin(size: coinSize, turn: coinSpin),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: center.dy + coinSize / 2 + 22,
                    child: Column(
                      children: [
                        ClipRect(
                          child: Align(
                            alignment: Alignment.center,
                            widthFactor: unveil.clamp(0.0, 1.0),
                            child: wordmark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: 150 * line,
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: fin.accentGradient,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Opacity(
                          opacity: tagline,
                          child: Transform.translate(
                            offset: Offset(0, 12 * (1 - tagline)),
                            child: Text(
                              'MONEY, BEAUTIFULLY CLEAR',
                              style: context.text.eyebrow.copyWith(
                                color: fin.accent,
                                letterSpacing: 4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  const _BurstPainter({
    required this.center,
    required this.strength,
    required this.rotation,
    required this.color,
  });

  final Offset center;
  final double strength;
  final double rotation;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0.01) return;
    final r = size.shortestSide * 0.7;
    canvas.drawCircle(
      center,
      r * 0.5,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.45 * strength),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r * 0.5)),
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    const rays = 12;
    final rayPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.28 * strength),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
    for (var i = 0; i < rays; i++) {
      final a = i * 2 * math.pi / rays;
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(math.cos(a - 0.06) * r, math.sin(a - 0.06) * r)
          ..lineTo(math.cos(a + 0.06) * r, math.sin(a + 0.06) * r)
          ..close(),
        rayPaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.strength != strength || old.rotation != rotation;
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.center,
    required this.progress,
    required this.colors,
  });

  final Offset center;
  final double progress;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final radius = 40 + progress * size.shortestSide * 0.55;
    final fade = 1 - progress;
    const count = 28;
    for (var i = 0; i < count; i++) {
      final a = i * 2 * math.pi / count + progress * 0.8;
      canvas.drawCircle(
        center + Offset(math.cos(a) * radius, math.sin(a) * radius),
        2.5 + 2 * (i % 3),
        Paint()..color = colors[i % colors.length].withValues(alpha: fade),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
