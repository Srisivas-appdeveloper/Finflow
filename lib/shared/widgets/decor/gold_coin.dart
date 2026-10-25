import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A 3D gold rupee coin. [turn] is the rotation around the vertical axis in
/// radians: the face narrows to its edge and the rim thickness shows as it
/// spins.
class GoldCoin extends StatelessWidget {
  const GoldCoin({super.key, required this.size, this.turn = 0});

  final double size;
  final double turn;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _CoinPainter(turn));
  }
}

class _CoinPainter extends CustomPainter {
  const _CoinPainter(this.turn);

  final double turn;

  static final _rupee = TextPainter(textDirection: TextDirection.ltr);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = size.center(Offset.zero);
    final cos = math.cos(turn);
    final sin = math.sin(turn);
    final faceW = (r * 2 * cos.abs()).clamp(r * 0.12, r * 2);
    final thickness = r * 0.2 * sin;

    // Rim: the face outline shifted by the visible thickness.
    final rim = Rect.fromCenter(
      center: c + Offset(thickness, 0),
      width: faceW,
      height: r * 2,
    );
    canvas.drawOval(rim, Paint()..color = const Color(0xFFB7791F));
    canvas.drawRect(
      Rect.fromLTRB(
        math.min(c.dx, c.dx + thickness),
        c.dy - r,
        math.max(c.dx, c.dx + thickness),
        c.dy + r,
      ),
      Paint()..color = const Color(0xFFB7791F),
    );

    // Face, lit from the top left; the light shifts as it turns.
    final face = Rect.fromCenter(center: c, width: faceW, height: r * 2);
    canvas.drawOval(
      face,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-1 + sin * 0.6, -1),
          end: Alignment(1 + sin * 0.6, 1),
          colors: const [
            Color(0xFFFFF1B8),
            Color(0xFFF59E0B),
            Color(0xFFB45309),
          ],
        ).createShader(face),
    );
    canvas.drawOval(
      face.deflate(r * 0.13),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..color = const Color(0x99FFF7D6),
    );

    // Embossed rupee sign, squeezed with the face.
    if (cos.abs() > 0.15) {
      _rupee.text = TextSpan(
        text: '₹',
        style: TextStyle(
          fontSize: r * 1.1,
          fontWeight: FontWeight.w800,
          color: const Color(0xC092400E),
        ),
      );
      _rupee.layout();
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(cos, 1);
      _rupee.paint(canvas, Offset(-_rupee.width / 2, -_rupee.height / 2));
      canvas.restore();
    }

    // Specular highlight.
    canvas.drawOval(
      Rect.fromCenter(
        center: c - Offset(faceW * 0.18, r * 0.42),
        width: faceW * 0.38,
        height: r * 0.3,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(_CoinPainter old) => old.turn != turn;
}
