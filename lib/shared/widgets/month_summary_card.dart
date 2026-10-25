import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/motion/motion.dart';
import '../../core/motion/rolling_number.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/money.dart';

/// The home hero: a holographic glass card showing the month's figures. It summarises recorded transactions only. It is not a payment
/// card or a credit card statement, so it carries no card number or chip.
///
/// Motion:
/// * enters by flipping up out of the table and settling,
/// * sways almost imperceptibly while idle,
/// * drag horizontally to turn it in 3D, or tap to flip it to the back,
/// * the light sheen and the shadow follow its rotation.
class MonthSummaryCard extends StatefulWidget {
  const MonthSummaryCard({
    super.key,
    required this.periodLabel,
    required this.net,
    required this.income,
    required this.spending,
    required this.transactionCount,
  });

  final String periodLabel;
  final Money net;
  final Money income;
  final Money spending;
  final int transactionCount;

  @override
  State<MonthSummaryCard> createState() => _MonthSummaryCardState();
}

class _MonthSummaryCardState extends State<MonthSummaryCard>
    with TickerProviderStateMixin {
  static const _aspect = 1.586;

  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  /// Rotation around the vertical axis, in radians. Unbounded so the card
  /// can be spun more than one turn.
  late final AnimationController _turn = AnimationController.unbounded(
    vsync: this,
  );

  double _width = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entry.isDismissed) {
      if (AppMotion.reduced(context)) {
        _entry.value = 1;
      } else {
        _entry.forward();
      }
    }
    if (AppMotion.ambientIn(context)) {
      if (!_sway.isAnimating) _sway.repeat();
    } else {
      _sway.stop();
    }
  }

  @override
  void dispose() {
    _entry.dispose();
    _sway.dispose();
    _turn.dispose();
    super.dispose();
  }

  void _settle(double target, double velocity) {
    if (AppMotion.reduced(context)) {
      _turn.value = target;
      return;
    }
    _turn.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 110, damping: 13),
        _turn.value,
        target,
        velocity,
      ),
    );
  }

  void _flip() {
    HapticFeedback.mediumImpact();
    final current = (_turn.value / math.pi).round() * math.pi;
    _settle(current + math.pi, 0);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _turn.stop();
    _turn.value += d.primaryDelta! / _width * math.pi;
  }

  void _onDragEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity! / _width * math.pi;
    // Project where a flick would carry the card, then snap to a face.
    final projected = _turn.value + velocity * 0.18;
    final target = (projected / math.pi).round() * math.pi;
    if ((target - _turn.value).abs() > 0.4) HapticFeedback.mediumImpact();
    _settle(target, velocity);
  }

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    final semantic =
        '${widget.periodLabel} summary. Net ${f.money(widget.net, signed: true)}. '
        'Income ${f.money(widget.income)}, spent ${f.money(widget.spending)}.';

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, 460.0);
        _width = width;
        final height = width / _aspect;

        return Semantics(
          button: true,
          label: semantic,
          hint: 'Double tap to flip',
          onTap: _flip,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: _flip,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            child: SizedBox(
              width: constraints.maxWidth,
              height: height + 34,
              child: AnimatedBuilder(
                animation: Listenable.merge([_entry, _sway, _turn]),
                builder: (context, _) => _buildScene(context, width, height),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScene(BuildContext context, double width, double height) {
    final e = AppMotion.silk.transform(_entry.value);
    final settle = AppMotion.spring.transform(_entry.value);
    final phase = _sway.value * 2 * math.pi;
    final idle = _sway.isAnimating ? 1.0 : 0.0;

    final angle = _turn.value + math.sin(phase) * 0.06 * idle;
    final tiltX = (1 - settle) * 1.25 + math.cos(phase) * 0.035 * idle;
    final lift = (1 - e) * 70;
    final scale = 0.84 + 0.16 * e;
    final opacity = Curves.easeOut.transform(
      const Interval(0, 0.35).transform(_entry.value),
    );
    final showBack = math.cos(angle) < 0;
    // Edge-on cards cast a narrow shadow.
    final facing = math.cos(angle).abs();

    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0011)
      ..translateByDouble(0, lift, 0, 1)
      ..rotateX(tiltX)
      ..rotateY(angle)
      ..scaleByDouble(scale, scale, 1, 1);

    final face = SizedBox(
      width: width,
      height: height,
      child: showBack
          ? Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(math.pi),
              child: _Face(
                back: true,
                light: math.sin(angle + math.pi),
                child: _BackContent(card: widget),
              ),
            )
          : _Face(
              back: false,
              light: math.sin(angle),
              child: _FrontContent(card: widget),
            ),
    );

    return Opacity(
      opacity: opacity,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Contact shadow on the "table".
          Positioned(
            top: height + 4,
            child: Container(
              width: width * (0.35 + 0.5 * facing) * scale,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.55 * e * (0.4 + 0.6 * facing),
                    ),
                    blurRadius: 26,
                    spreadRadius: -4,
                  ),
                ],
              ),
            ),
          ),
          Transform(alignment: Alignment.center, transform: m, child: face),
        ],
      ),
    );
  }
}

/// Holographic glass card: a vivid gradient with iridescent bands, soft
/// light orbs, flowing lines, a glass highlight and a rim light. [light]
/// (-1..1) moves the reflection as the card turns.
class _Face extends StatelessWidget {
  const _Face({required this.back, required this.light, required this.child});

  final bool back;
  final double light;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: fin.heroGradient,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC026D3).withValues(alpha: 0.35),
            blurRadius: 40,
            spreadRadius: -10,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(painter: _HoloPainter(back: back)),
            ),
            CustomPaint(painter: _SheenPainter(light)),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
              child: child,
            ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoloPainter extends CustomPainter {
  const _HoloPainter({required this.back});

  final bool back;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Light orbs glowing inside the card.
    void orb(Offset c, double r, Color color, double a) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: a),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    orb(
      Offset(w * (back ? 0.2 : 0.85), h * 0.15),
      h * 0.9,
      const Color(0xFF22D3EE),
      0.45,
    );
    orb(
      Offset(w * (back ? 0.9 : 0.1), h * 0.95),
      h * 0.8,
      const Color(0xFFFBBF24),
      0.35,
    );

    // Iridescent diagonal bands.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.softLight
        ..shader = const LinearGradient(
          begin: Alignment(-1, -1),
          end: Alignment(1, 1),
          colors: [
            Color(0x00FFFFFF),
            Color(0x66FFFFFF),
            Color(0x00FFFFFF),
            Color(0x5522D3EE),
            Color(0x00FFFFFF),
          ],
          stops: [0.1, 0.3, 0.45, 0.65, 0.85],
        ).createShader(Offset.zero & size),
    );

    // Flowing lines.
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 7; i++) {
      line.color = Colors.white.withValues(alpha: 0.06 + i * 0.018);
      final path = Path();
      final base = h * (0.5 + i * 0.065);
      for (var x = 0.0; x <= w; x += 6) {
        final y =
            base +
            math.sin(x / w * math.pi * 2 + i * 0.5 + (back ? 1.5 : 0)) *
                (10 + i * 2);
        x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(path, line);
    }

    // Concentric rings, top right.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.18);
    final rc = Offset(w * (back ? 0.12 : 0.9), h * 0.12);
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(rc, h * 0.12 * i, ring);
    }

    // Glass highlight across the top.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.5),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.5)),
    );
  }

  @override
  bool shouldRepaint(_HoloPainter old) => old.back != back;
}

class _SheenPainter extends CustomPainter {
  const _SheenPainter(this.light);

  final double light;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * (0.5 - light * 0.9);
    final band = Rect.fromLTWH(
      x - size.width * 0.45,
      0,
      size.width * 0.9,
      size.height,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: const Alignment(-1, -0.6),
          end: const Alignment(1, 0.6),
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.2),
            const Color(0xFFA5F3FC).withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0.2, 0.47, 0.53, 0.8],
        ).createShader(band),
    );
  }

  @override
  bool shouldRepaint(_SheenPainter old) => old.light != light;
}

/// White wordmark with a faint pearl gradient.
class _Engraved extends StatelessWidget {
  const _Engraved(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => const LinearGradient(
        colors: [Colors.white, Color(0xFFE0E7FF), Colors.white],
      ).createShader(rect),
      child: Text(text, style: style),
    );
  }
}

class _FrontContent extends StatelessWidget {
  const _FrontContent({required this.card});

  final MonthSummaryCard card;

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    final fin = context.fin;
    final eyebrow = context.text.eyebrow.copyWith(color: fin.onHeroMuted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _Engraved(
                    'FINFLOW',
                    style: context.text.titleLarge!.copyWith(
                      letterSpacing: 4,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        Text('NET · ${card.periodLabel.toUpperCase()}', style: eyebrow),
        const SizedBox(height: AppSpacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: RollingNumberText(
            f.money(card.net, signed: true),
            delay: const Duration(milliseconds: 650),
            duration: const Duration(milliseconds: 1500),
            style: context.text.displayMedium!.tabular.copyWith(
              color: fin.onHero,
              fontSize: 38,
            ),
          ),
        ),
        const Spacer(),
        Row(
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    _Pair(label: 'IN', value: f.money(card.income)),
                    const SizedBox(width: AppSpacing.xl),
                    _Pair(label: 'OUT', value: f.money(card.spending)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Icon(
              Icons.threesixty_rounded,
              size: 16,
              color: fin.onHeroMuted.withValues(alpha: 0.7),
            ),
          ],
        ),
      ],
    );
  }
}

class _BackContent extends StatelessWidget {
  const _BackContent({required this.card});

  final MonthSummaryCard card;

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    final fin = context.fin;
    final rate = card.income.isZero ? null : card.net.minor / card.income.minor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${card.periodLabel.toUpperCase()} IN NUMBERS',
          textAlign: TextAlign.center,
          style: context.text.eyebrow.copyWith(color: fin.onHero),
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(child: _Stat('Income', f.money(card.income))),
            Expanded(child: _Stat('Spent', f.money(card.spending))),
          ],
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(child: _Stat('Transactions', '${card.transactionCount}')),
            Expanded(
              child: _Stat(
                'Kept',
                rate == null ? '—' : f.percent(rate.clamp(-9.99, 9.99)),
              ),
            ),
          ],
        ),
        const Spacer(),
      ],
    );
  }
}

class _Pair extends StatelessWidget {
  const _Pair({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: context.text.eyebrow.copyWith(color: fin.onHeroMuted),
        ),
        const SizedBox(height: 2),
        RollingNumberText(
          value,
          delay: const Duration(milliseconds: 900),
          style: context.text.labelLarge!.tabular.copyWith(
            color: fin.onHero,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: context.text.eyebrow.copyWith(color: fin.onHeroMuted),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: RollingNumberText(
            value,
            style: context.text.titleMedium!.tabular.copyWith(
              color: fin.onHero,
              fontWeight: FontWeight.w300,
              fontSize: 20,
            ),
          ),
        ),
      ],
    );
  }
}
