import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/transaction_category.dart';
import '../../shared/widgets/category_style.dart';
import '../../shared/widgets/decor/glass_orb.dart';
import '../../shared/widgets/decor/gold_coin.dart';

/// Base for the onboarding illustrations: a looping timeline that restarts
/// whenever the scene becomes [active], like replaying a short clip.
abstract class _Scene extends StatefulWidget {
  const _Scene({super.key, required this.active});

  final bool active;

  /// Length of one loop.
  Duration get loop => const Duration(seconds: 6);

  Widget paint(BuildContext context, Size size, double t, double seconds);

  @override
  State<_Scene> createState() => _SceneState();
}

class _SceneState extends State<_Scene> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.loop,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Scene old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  void _sync() {
    if (AppMotion.reduced(context) || !AppMotion.intro) {
      // A representative still frame.
      _c.value = 0.62;
      return;
    }
    if (widget.active) {
      _c
        ..value = 0
        ..repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Scenes are composed on a fixed canvas and scaled uniformly to fit,
  /// like a video frame, so they look the same on every screen.
  static const _canvas = Size(340, 360);

  @override
  Widget build(BuildContext context) {
    // Decorative: the page text carries the meaning. Illustrations do not
    // reflow with the user's text size.
    return ExcludeSemantics(
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: FittedBox(
          child: SizedBox.fromSize(
            size: _canvas,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => widget.paint(
                context,
                _canvas,
                _c.value,
                _c.value * widget.loop.inMilliseconds / 1000,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Progress of [t] through [begin]..[end], shaped by [curve].
double _seg(
  double t,
  double begin,
  double end, [
  Curve curve = AppMotion.silk,
]) => curve.transform(Interval(begin, end).transform(t.clamp(0.0, 1.0)));

// ---------------------------------------------------------------------------
// 1. Track: a glass phone fills with transactions while coins drop beside it.
// ---------------------------------------------------------------------------

class TrackScene extends _Scene {
  const TrackScene({super.key, required super.active});

  /// Illustration rows: a category icon with placeholder bars of varying
  /// length. No names or amounts, so nothing reads as real data.
  static const _rows = [
    (TransactionCategory.dining, 0.62, 0.3),
    (TransactionCategory.transport, 0.48, 0.26),
    (TransactionCategory.groceries, 0.7, 0.34),
    (TransactionCategory.salary, 0.55, 0.38),
  ];

  @override
  Widget paint(BuildContext context, Size size, double t, double seconds) {
    final fin = context.fin;
    final phoneW = math.min(size.width * 0.56, 230.0);
    final enter = _seg(t, 0, 0.14, AppMotion.spring);
    // Everything fades out briefly at the end so the loop restarts cleanly.
    final outro = 1 - _seg(t, 0.9, 1, Curves.easeIn);

    final phone = Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..translateByDouble(0, (1 - enter) * 120, 0, 1)
        ..rotateX(0.12)
        ..rotateY(math.sin(seconds * 0.9) * 0.14),
      child: Opacity(
        opacity: enter.clamp(0.0, 1.0),
        child: Container(
          width: phoneW,
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.75),
                Colors.white.withValues(alpha: 0.45),
              ],
            ),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: fin.accent.withValues(alpha: 0.35),
                blurRadius: 40,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 54,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E1130).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Headline placeholder: a short accent bar and a longer bar
              // that grows in, standing in for a total.
              _bar(width: 40, height: 6, color: fin.accent),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: 0.25 + 0.5 * _seg(t, 0.1, 0.5),
                  child: _bar(
                    height: 18,
                    color: const Color(0xFF0E1130).withValues(alpha: 0.75),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < _rows.length; i++) _row(context, i, t, outro),
            ],
          ),
        ),
      ),
    );

    // Coins dropping in beside the phone, each landing with a bounce.
    final coins = <Widget>[];
    const drops = [
      (0.30, -0.42, 0.78, 46.0),
      (0.42, 0.40, 0.70, 38.0),
      (0.54, -0.30, 0.94, 32.0),
    ];
    for (final (start, x, y, d) in drops) {
      final fall = _seg(t, start, start + 0.18, Curves.bounceOut);
      final spin = (1 - _seg(t, start, start + 0.26)) * math.pi * 5;
      final visible = t > start;
      final cx = size.width / 2 + x * size.width;
      final cy = -d + (size.height * y + d) * fall;
      coins.add(
        Positioned(
          left: cx - d / 2,
          top: cy - d / 2,
          child: Opacity(
            opacity: visible ? outro : 0,
            child: GoldCoin(size: d, turn: spin),
          ),
        ),
      );
      // Contact shadow grows as the coin lands.
      coins.add(
        Positioned(
          left: cx - d * 0.45,
          top: size.height * y + d * 0.42,
          child: Opacity(
            opacity: visible ? 0.25 * fall * outro : 0,
            child: Container(
              width: d * 0.9 * fall,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ..._sparkles(size, seconds, fin.accent),
        Center(child: phone),
        ...coins,
      ],
    );
  }

  Widget _row(BuildContext context, int i, double t, double outro) {
    final (category, titleWidth, amountWidth) = _rows[i];
    final p = _seg(t, 0.16 + i * 0.09, 0.34 + i * 0.09, AppMotion.settle);
    final color = CategoryStyle.color(context, category);
    final income = category.isIncome ?? false;
    return Opacity(
      opacity: (p.clamp(0.0, 1.0)) * outro,
      child: Transform.translate(
        offset: Offset((1 - p) * 120, 0),
        child: Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CategoryStyle.icon(category),
                  size: 14,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: titleWidth,
                    child: _bar(
                      height: 7,
                      color: const Color(0xFF0E1130).withValues(alpha: 0.28),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 120 * amountWidth,
                child: _bar(
                  height: 7,
                  color: income
                      ? const Color(0xFF047857).withValues(alpha: 0.7)
                      : const Color(0xFF0E1130).withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded placeholder bar used in the illustrations.
Widget _bar({double? width, required double height, required Color color}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(height / 2),
    ),
  );
}

// ---------------------------------------------------------------------------
// 2. Understand: a ring chart draws itself while categories orbit it.
// ---------------------------------------------------------------------------

class UnderstandScene extends _Scene {
  const UnderstandScene({super.key, required super.active});

  static const _segments = [
    (TransactionCategory.bills, 0.30),
    (TransactionCategory.shopping, 0.24),
    (TransactionCategory.dining, 0.18),
    (TransactionCategory.transport, 0.16),
    (TransactionCategory.groceries, 0.12),
  ];

  @override
  Widget paint(BuildContext context, Size size, double t, double seconds) {
    final fin = context.fin;
    final colors = [
      for (final (c, _) in _segments) CategoryStyle.color(context, c),
    ];
    final r = math.min(size.width, size.height) * 0.26;
    final center = Offset(size.width / 2, size.height * 0.46);
    final draw = _seg(t, 0.04, 0.42);
    final outro = 1 - _seg(t, 0.9, 1, Curves.easeIn);

    final bubbles = <(double, Widget)>[];
    for (var i = 0; i < _segments.length; i++) {
      final appear = _seg(t, 0.2 + i * 0.07, 0.4 + i * 0.07, AppMotion.settle);
      final angle = i * 2 * math.pi / _segments.length + seconds * 0.45;
      final x = math.cos(angle) * r * 1.62;
      final y = math.sin(angle) * r * 1.05;
      // Depth from the orbit: nearer bubbles are larger and drawn on top.
      final depth = (math.sin(angle) + 1) / 2;
      final scale = (0.78 + 0.32 * depth) * appear;
      bubbles.add((
        depth,
        Positioned(
          left: center.dx + x - 22,
          top: center.dy + y - 22,
          child: Opacity(
            opacity: (appear.clamp(0.0, 1.0)) * outro,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, colors[i].withValues(alpha: 0.35)],
                  ),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: colors[i].withValues(alpha: 0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  CategoryStyle.icon(_segments[i].$1),
                  size: 21,
                  color: colors[i],
                ),
              ),
            ),
          ),
        ),
      ));
    }
    bubbles.sort((a, b) => a.$1.compareTo(b.$1));
    final back = bubbles.where((b) => b.$1 < 0.5).map((b) => b.$2);
    final front = bubbles.where((b) => b.$1 >= 0.5).map((b) => b.$2);

    // Mini bars growing below.
    const bars = [0.35, 0.6, 0.45, 0.8, 0.55, 1.0, 0.7];
    final barRow = Positioned(
      left: center.dx - 84,
      top: center.dy + r * 1.55,
      child: Opacity(
        opacity: outro,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < bars.length; i++)
              Container(
                width: 14,
                height:
                    46 *
                    bars[i] *
                    _seg(t, 0.42 + i * 0.03, 0.62 + i * 0.03, AppMotion.settle),
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [fin.accent, AppPalette.cyan],
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ..._sparkles(size, seconds, fin.accent),
        ...back,
        Positioned.fromRect(
          rect: Rect.fromCircle(center: center, radius: r + 14),
          child: Opacity(
            opacity: outro,
            child: CustomPaint(
              painter: _RingPainter(
                progress: draw,
                shares: [for (final (_, s) in _segments) s],
                colors: colors,
                spin: seconds * 0.15,
              ),
              child: Center(
                // Centre icon instead of a figure: illustration only.
                child: Icon(
                  Icons.donut_large_rounded,
                  size: r * 0.55,
                  color: fin.accent,
                ),
              ),
            ),
          ),
        ),
        ...front,
        barRow,
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.shares,
    required this.colors,
    required this.spin,
  });

  final double progress;
  final List<double> shares;
  final List<Color> colors;
  final double spin;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(14);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..color = Colors.white.withValues(alpha: 0.35);
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);

    const gap = 0.06;
    var start = -math.pi / 2 + spin;
    var drawn = 0.0;
    final limit = progress * 2 * math.pi;
    for (var i = 0; i < shares.length; i++) {
      final sweep = shares[i] * 2 * math.pi - gap;
      final visible = math.min(sweep, limit - drawn);
      if (visible > 0) {
        canvas.drawArc(
          rect,
          start,
          visible,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 20
            ..strokeCap = StrokeCap.round
            ..color = colors[i],
        );
      }
      start += sweep + gap;
      drawn += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.spin != spin;
}

// ---------------------------------------------------------------------------
// 3. Private: a shield orb with radar pulses, a check drawing itself and
// floating badges.
// ---------------------------------------------------------------------------

class PrivateScene extends _Scene {
  const PrivateScene({super.key, required super.active});

  @override
  Widget paint(BuildContext context, Size size, double t, double seconds) {
    final fin = context.fin;
    final center = Offset(size.width / 2, size.height * 0.45);
    final orbSize = math.min(size.width, size.height) * 0.34;
    final pop = _seg(t, 0, 0.18, AppMotion.spring);
    final check = _seg(t, 0.3, 0.48);
    final outro = 1 - _seg(t, 0.92, 1, Curves.easeIn);

    const badges = [
      (Icons.phone_android_rounded, 'On-device', -0.36, 0.78),
      (Icons.tune_rounded, 'Your control', 0.3, 0.86),
      (Icons.verified_user_rounded, 'Consent first', -0.02, 0.97),
    ];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ..._sparkles(size, seconds, fin.accent),
        // Radar pulses.
        Positioned.fill(
          child: CustomPaint(
            painter: _PulsePainter(
              center: center,
              base: orbSize * 0.55,
              seconds: seconds,
              color: fin.accent,
              strength: pop.clamp(0.0, 1.0) * outro,
            ),
          ),
        ),
        // Orbiting particles.
        for (var i = 0; i < 8; i++)
          Builder(
            builder: (context) {
              final a = i * math.pi / 4 + seconds * 0.8;
              final rr = orbSize * 0.95;
              return Positioned(
                left: center.dx + math.cos(a) * rr - 4,
                top: center.dy + math.sin(a) * rr * 0.6 - 4,
                child: Opacity(
                  opacity: 0.8 * pop.clamp(0.0, 1.0) * outro,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i.isEven ? AppPalette.cyan : fin.accent,
                    ),
                  ),
                ),
              );
            },
          ),
        Positioned(
          left: center.dx - orbSize / 2,
          top: center.dy - orbSize / 2,
          child: Opacity(
            opacity: outro,
            child: Transform.scale(
              scale: pop,
              child: GlassOrb(icon: Icons.lock_rounded, size: orbSize),
            ),
          ),
        ),
        // Check badge drawing itself.
        Positioned(
          left: center.dx + orbSize * 0.22,
          top: center.dy + orbSize * 0.18,
          child: Opacity(
            opacity: outro * (check > 0 ? 1 : 0),
            child: Transform.scale(
              scale: _seg(t, 0.28, 0.4, AppMotion.spring),
              child: Container(
                width: orbSize * 0.36,
                height: orbSize * 0.36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fin.income,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: fin.income.withValues(alpha: 0.5),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: CustomPaint(painter: _CheckPainter(check)),
              ),
            ),
          ),
        ),
        for (var i = 0; i < badges.length; i++)
          Builder(
            builder: (context) {
              final (icon, label, x, y) = badges[i];
              final rise = _seg(
                t,
                0.45 + i * 0.08,
                0.65 + i * 0.08,
                AppMotion.settle,
              );
              final bob = math.sin(seconds * 1.6 + i) * 4;
              return Positioned(
                left: size.width / 2 + x * size.width - 62,
                top: size.height * y + (1 - rise) * 40 + bob - 18,
                child: Opacity(
                  opacity: rise.clamp(0.0, 1.0) * outro,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white),
                      boxShadow: [
                        BoxShadow(
                          color: fin.accent.withValues(alpha: 0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 15, color: fin.accent),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0E1130),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _PulsePainter extends CustomPainter {
  const _PulsePainter({
    required this.center,
    required this.base,
    required this.seconds,
    required this.color,
    required this.strength,
  });

  final Offset center;
  final double base;
  final double seconds;
  final Color color;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final p = ((seconds / 2.2) + i / 3) % 1;
      canvas.drawCircle(
        center,
        base + p * base * 1.6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: (1 - p) * 0.5 * strength),
      );
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) =>
      old.seconds != seconds || old.strength != strength;
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.27, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.74, size.height * 0.36);
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.1
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}

/// Twinkling four-point stars scattered around a scene.
List<Widget> _sparkles(Size size, double seconds, Color color) {
  const spots = [
    (0.12, 0.12),
    (0.86, 0.18),
    (0.08, 0.62),
    (0.92, 0.7),
    (0.5, 0.04),
  ];
  return [
    for (var i = 0; i < spots.length; i++)
      Positioned(
        left: size.width * spots[i].$1 - 8,
        top: size.height * spots[i].$2 - 8,
        child: Transform.scale(
          scale: 0.4 + 0.6 * ((math.sin(seconds * 2.4 + i * 1.7) + 1) / 2),
          child: Icon(Icons.auto_awesome, size: 16, color: color),
        ),
      ),
  ];
}
