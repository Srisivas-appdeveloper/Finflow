import 'package:flutter/material.dart';

import 'motion.dart';

/// Renders [text] with every digit on its own rolling drum, like an
/// odometer. On first appearance each digit spins into place from left to
/// right; when the text changes, only the digits that differ roll.
///
/// Non-digit characters (currency symbols, separators, signs) are drawn
/// statically. Use with tabular figures so digits share one width.
class RollingNumberText extends StatelessWidget {
  const RollingNumberText(
    this.text, {
    super.key,
    this.style,
    this.duration = const Duration(milliseconds: 1100),
    this.stagger = const Duration(milliseconds: 45),
    this.delay = Duration.zero,
  });

  final String text;
  final TextStyle? style;
  final Duration duration;
  final Duration stagger;

  /// Extra delay before the first digit starts, to sequence with other
  /// entrance animations.
  final Duration delay;

  static bool _isDigit(int c) => c >= 48 && c <= 57;

  @override
  Widget build(BuildContext context) {
    final resolved = DefaultTextStyle.of(context).style.merge(style);
    final scaler = MediaQuery.textScalerOf(context);
    final painter = TextPainter(
      text: TextSpan(text: '0', style: resolved),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final digitSize = painter.size;
    painter.dispose();

    final chars = text.runes.toList();
    var digitIndex = 0;
    final children = <Widget>[];
    for (var i = 0; i < chars.length; i++) {
      final c = chars[i];
      // Key by position from the right so digits keep their drum (and
      // state) when the number gains or loses leading digits.
      final fromRight = chars.length - i;
      if (_isDigit(c)) {
        children.add(
          _RollingDigit(
            key: ValueKey('d$fromRight'),
            digit: c - 48,
            size: digitSize,
            style: resolved,
            scaler: scaler,
            duration: duration,
            delay: delay + stagger * digitIndex,
          ),
        );
        digitIndex++;
      } else {
        children.add(
          Text(
            String.fromCharCode(c),
            key: ValueKey('s$fromRight$c'),
            style: resolved,
            textScaler: scaler,
          ),
        );
      }
    }

    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }
}

class _RollingDigit extends StatefulWidget {
  const _RollingDigit({
    super.key,
    required this.digit,
    required this.size,
    required this.style,
    required this.scaler,
    required this.duration,
    required this.delay,
  });

  final int digit;
  final Size size;
  final TextStyle style;
  final TextScaler scaler;
  final Duration duration;
  final Duration delay;

  @override
  State<_RollingDigit> createState() => _RollingDigitState();
}

class _RollingDigitState extends State<_RollingDigit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _position;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + widget.duration;
    _controller = AnimationController(vsync: this, duration: total);
    // One full turn of the drum, landing on the digit.
    _position =
        Tween<double>(
          begin: widget.digit - 10.0,
          end: widget.digit.toDouble(),
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(
              widget.delay.inMicroseconds / total.inMicroseconds,
              1,
              curve: AppMotion.settle,
            ),
          ),
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isDismissed) {
      if (AppMotion.reduced(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void didUpdateWidget(_RollingDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.digit != widget.digit) {
      final current = _position.value;
      _position = Tween<double>(
        begin: current,
        end: widget.digit.toDouble(),
      ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.settle));
      _controller
        ..duration = widget.duration * 0.6
        ..forward(from: AppMotion.reduced(context) ? 1 : 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.size.height;
    return SizedBox.fromSize(
      size: widget.size,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _position,
          builder: (context, _) {
            final p = _position.value;
            final base = p.floor();
            final frac = p - base;
            // While moving, each digit fades by how far it is from the
            // window centre (via text colour, so no offscreen layer).
            final color = widget.style.color ?? const Color(0xFF000000);
            Widget digit(int value, double dy) {
              final visibility = (1 - (dy.abs() / h)).clamp(0.0, 1.0);
              return Transform.translate(
                offset: Offset(0, dy),
                child: Text(
                  '${((value % 10) + 10) % 10}',
                  style: widget.style.copyWith(
                    color: color.withValues(alpha: color.a * visibility),
                  ),
                  textScaler: widget.scaler,
                ),
              );
            }

            if (frac < 0.001) return digit(base, 0);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                digit(base, -frac * h),
                digit(base + 1, (1 - frac) * h),
              ],
            );
          },
        ),
      ),
    );
  }
}
