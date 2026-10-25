import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show PipelineOwner;

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_colors.dart';

/// The app's backdrop: vivid colour fields with finance objects floating in
/// them (a 3D rupee coin, a coin stack, rising growth bars and glossy
/// spheres). Glass panels show a blurred view of this scene, which is what
/// gives them their colour.
///
/// When the scene is still (the default), it is rendered once into an image,
/// together with a pre-blurred copy. Glass panels inside [child] draw their
/// slice of the blurred copy (see [BackdropScope]) instead of blurring the
/// screen live every frame, which keeps animations smooth. With ambient
/// motion enabled the scene drifts and is painted live.
///
/// Pass [accent] to add a glow in another colour (e.g. on the details page).
class AmbientBackground extends StatefulWidget {
  const AmbientBackground({
    super.key,
    this.accent,
    this.objects = true,
    this.child,
  });

  final Color? accent;

  /// Whether to draw the floating finance objects. Pages with centred
  /// content (e.g. details) show only the colour fields.
  final bool objects;

  /// Content laid over the background; its glass panels use the cached
  /// blurred backdrop.
  final Widget? child;

  /// Blur radius (logical pixels) baked into the cached backdrop.
  static const blurSigma = 16.0;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  // Every instance derives its phase from one app-wide clock, so copies of
  // the background stay in sync.
  static final _clock = Stopwatch()..start();
  static const _period = Duration(seconds: 24);

  /// The blurred copy is rendered at a quarter of the resolution: blur
  /// removes the detail anyway, and it is 16x cheaper to keep.
  static const _blurScale = 0.25;

  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: _period,
  );

  final _hostKey = GlobalKey();
  ui.Image? _sharp;
  ui.Image? _blurred;
  Object? _renderedFor;

  double get _phase => AppMotion.ambient
      ? (_clock.elapsedMilliseconds % _period.inMilliseconds) /
            _period.inMilliseconds
      : 0;

  bool get _live => AppMotion.ambientIn(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_live) {
      if (!_drift.isAnimating) _drift.repeat();
    } else {
      _drift.stop();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    _sharp?.dispose();
    _blurred?.dispose();
    super.dispose();
  }

  _ScenePainter _painter(BuildContext context) {
    final theme = Theme.of(context);
    return _ScenePainter(
      drift: _drift,
      phase: () => _phase,
      background: theme.scaffoldBackgroundColor,
      fields: context.fin.backdrop,
      accent: widget.accent,
      objects: widget.objects,
      dark: theme.brightness == Brightness.dark,
    );
  }

  /// Renders the still scene and its blurred copy for [size].
  void _render(Size size, double dpr, _ScenePainter painter, Object key) {
    if (size.isEmpty) return;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(dpr);
    painter.paint(canvas, size);
    final picture = recorder.endRecording();
    final sharp = picture.toImageSync(
      (size.width * dpr).ceil(),
      (size.height * dpr).ceil(),
    );
    picture.dispose();

    final bw = (sharp.width * _blurScale).ceil();
    final bh = (sharp.height * _blurScale).ceil();
    final sigma = AmbientBackground.blurSigma * dpr * _blurScale;
    final blurRecorder = ui.PictureRecorder();
    Canvas(blurRecorder)
      ..saveLayer(
        null,
        Paint()
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: TileMode.clamp,
          ),
      )
      ..drawImageRect(
        sharp,
        Rect.fromLTWH(0, 0, sharp.width.toDouble(), sharp.height.toDouble()),
        Rect.fromLTWH(0, 0, bw.toDouble(), bh.toDouble()),
        Paint()..filterQuality = FilterQuality.medium,
      )
      ..restore();
    final blurPicture = blurRecorder.endRecording();
    final blurred = blurPicture.toImageSync(bw, bh);
    blurPicture.dispose();

    _sharp?.dispose();
    _blurred?.dispose();
    _sharp = sharp;
    _blurred = blurred;
    _renderedFor = key;
  }

  @override
  Widget build(BuildContext context) {
    final painter = _painter(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final live = _live;
        if (!live) {
          final key = (
            size,
            dpr,
            painter.background,
            painter.accent,
            painter.objects,
            painter.dark,
          );
          if (key != _renderedFor) _render(size, dpr, painter, key);
        }

        final scene = live || _sharp == null
            ? RepaintBoundary(
                child: CustomPaint(
                  painter: painter,
                  child: const SizedBox.expand(),
                ),
              )
            : RawImage(image: _sharp, fit: BoxFit.fill);

        return BackdropScope(
          blurred: live ? null : _blurred,
          hostKey: _hostKey,
          child: Stack(
            key: _hostKey,
            fit: StackFit.expand,
            children: [
              scene,
              if (widget.child != null)
                // Scrolling can move glass panels without repainting them;
                // tell their backdrop slices to re-align.
                NotificationListener<ScrollNotification>(
                  onNotification: (_) {
                    BackdropReposition.instance.ping();
                    return false;
                  },
                  child: widget.child!,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Gives glass panels access to the pre-blurred backdrop of the nearest
/// [AmbientBackground], and the host box to align their slice with.
class BackdropScope extends InheritedWidget {
  const BackdropScope({
    super.key,
    required this.blurred,
    required this.hostKey,
    required super.child,
  });

  /// Null while the scene animates (glass then blurs live).
  final ui.Image? blurred;
  final GlobalKey hostKey;

  static BackdropScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BackdropScope>();

  @override
  bool updateShouldNotify(BackdropScope old) =>
      old.blurred != blurred || old.hostKey != hostKey;
}

/// Paints the part of [image] (a blurred copy of the host's background)
/// that lies directly behind this box, so it looks exactly like a live
/// backdrop blur of the background.
class BackdropSlice extends LeafRenderObjectWidget {
  const BackdropSlice({
    super.key,
    required this.image,
    required this.hostKey,
    this.opacity = 1,
  });

  final ui.Image image;
  final GlobalKey hostKey;
  final double opacity;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBackdropSlice(image, hostKey, opacity);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderBackdropSlice)
      ..image = image
      ..hostKey = hostKey
      ..opacity = opacity;
  }
}

/// Signals that content has moved relative to the background without being
/// repainted (e.g. a whole tab sliding as a cached layer), so backdrop slices
/// must re-align.
class BackdropReposition extends ChangeNotifier {
  BackdropReposition._();

  static final instance = BackdropReposition._();

  void ping() => notifyListeners();
}

class _RenderBackdropSlice extends RenderBox {
  _RenderBackdropSlice(this._image, this.hostKey, this._opacity);

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    BackdropReposition.instance.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    BackdropReposition.instance.removeListener(markNeedsPaint);
    super.detach();
  }

  ui.Image _image;
  set image(ui.Image value) {
    if (identical(value, _image)) return;
    _image = value;
    markNeedsPaint();
  }

  GlobalKey hostKey;

  double _opacity;
  set opacity(double value) {
    if (value == _opacity) return;
    _opacity = value;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {
    final host = hostKey.currentContext?.findRenderObject();
    if (host is! RenderBox || !host.attached || host.size.isEmpty) return;
    // Position of this box relative to the background, in logical pixels.
    // Both are measured in global space, so shared transforms (e.g. a whole
    // page sliding) cancel out.
    final rel = localToGlobal(Offset.zero) - host.localToGlobal(Offset.zero);
    final sx = _image.width / host.size.width;
    final sy = _image.height / host.size.height;
    context.canvas.drawImageRect(
      _image,
      Rect.fromLTWH(
        rel.dx * sx,
        rel.dy * sy,
        size.width * sx,
        size.height * sy,
      ),
      offset & size,
      Paint()
        ..filterQuality = FilterQuality.low
        ..color = Color.fromRGBO(0, 0, 0, _opacity),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.drift,
    required this.phase,
    required this.background,
    required this.fields,
    required this.accent,
    required this.objects,
    required this.dark,
  }) : super(repaint: drift);

  /// Repaint trigger only; the actual phase comes from [phase].
  final Animation<double> drift;
  final double Function() phase;
  final Color background;
  final List<Color> fields;
  final Color? accent;
  final bool objects;
  final bool dark;

  static final _rupee = TextPainter(textDirection: TextDirection.ltr);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = phase() * 2 * math.pi;
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    // 1. Colour fields.
    final k = dark ? 0.55 : 0.5;
    void field(Offset c, double r, Color color, double a) {
      final rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: a * k),
              color.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }

    field(
      Offset(w * (0.1 + 0.08 * math.sin(p)), h * 0.08),
      w * 0.95,
      fields[0],
      1,
    );
    field(
      Offset(w * (0.95 - 0.06 * math.cos(p)), h * 0.3),
      w * 0.85,
      fields[1],
      0.9,
    );
    field(
      Offset(w * 0.15, h * (0.58 + 0.04 * math.sin(p + 1))),
      w * 0.8,
      fields[2],
      0.7,
    );
    field(
      Offset(w * (0.9 + 0.05 * math.sin(p + 2)), h * 0.78),
      w * 0.8,
      fields[3],
      0.75,
    );
    field(Offset(w * 0.4, h * 1.02), w * 0.7, fields[4], 0.5);
    if (accent != null) {
      field(Offset(w * 0.5, h * 0.14), w * 0.8, accent!, 0.9);
    }

    if (!objects) return;
    final o = dark ? 1.0 : 0.85;
    double bob(double phase, double amp) => math.sin(p + phase) * amp;

    // 2. Rupee coin, peeking in from the right edge mid-screen (the top
    // stays clear for the header).
    _coin(
      canvas,
      Offset(w * 0.9, h * 0.44 + bob(0, 8)),
      w * 0.15,
      tilt: 0.35 + 0.08 * math.sin(p),
      opacity: o,
    );

    // 3. Coin stack, mid left.
    final stackBase = Offset(w * 0.1, h * 0.66 + bob(1.4, 6));
    for (var i = 0; i < 5; i++) {
      _coin(
        canvas,
        stackBase - Offset(0, i * w * 0.032),
        w * 0.085,
        tilt: 0.78,
        opacity: o * 0.95,
        mark: i == 4,
      );
    }

    // 4. Rising growth bars, right.
    _bars(canvas, Offset(w * 0.68, h * 0.8 + bob(2.2, 7)), w * 0.24, o);

    // 5. Glossy spheres.
    _sphere(
      canvas,
      Offset(w * 0.08 + bob(0.7, 6), h * 0.36),
      w * 0.07,
      fields[3],
      o,
    );
    _sphere(
      canvas,
      Offset(w * 0.62, h * 0.9 + bob(2.9, 6)),
      w * 0.05,
      fields[2],
      o,
    );
    _sphere(
      canvas,
      Offset(w * 0.38 + bob(1.9, 5), h * 0.47),
      w * 0.035,
      fields[4],
      o,
    );
  }

  /// A gold coin seen at an angle: an edge band, then the face with an
  /// embossed rupee sign and a specular highlight.
  void _coin(
    Canvas canvas,
    Offset c,
    double r, {
    required double tilt,
    required double opacity,
    bool mark = true,
  }) {
    final squash = math.cos(tilt).clamp(0.25, 1.0);
    final face = Rect.fromCenter(
      center: c,
      width: r * 2,
      height: r * 2 * squash,
    );
    final thickness = r * 0.22 * math.sin(tilt).abs() + r * 0.05;

    // Edge (thickness).
    canvas.drawOval(
      face.shift(Offset(0, thickness)),
      Paint()..color = const Color(0xFFB7791F).withValues(alpha: opacity),
    );
    canvas.drawRect(
      Rect.fromLTRB(face.left, c.dy, face.right, c.dy + thickness),
      Paint()..color = const Color(0xFFB7791F).withValues(alpha: opacity),
    );
    // Face.
    canvas.drawOval(
      face,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFDE68A).withValues(alpha: opacity),
            const Color(0xFFF59E0B).withValues(alpha: opacity),
            const Color(0xFFB45309).withValues(alpha: opacity),
          ],
        ).createShader(face),
    );
    // Inner rim.
    canvas.drawOval(
      face.deflate(r * 0.14),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..color = const Color(0xFFFFF7D6).withValues(alpha: 0.55 * opacity),
    );
    if (mark) {
      _rupee.text = TextSpan(
        text: '₹',
        style: TextStyle(
          fontSize: r * 1.05,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF92400E).withValues(alpha: 0.75 * opacity),
        ),
      );
      _rupee.layout();
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(1, squash);
      _rupee.paint(canvas, Offset(-_rupee.width / 2, -_rupee.height / 2));
      canvas.restore();
    }
    // Specular highlight.
    canvas.drawOval(
      Rect.fromCenter(
        center: c - Offset(r * 0.35, r * 0.4 * squash),
        width: r * 0.7,
        height: r * 0.32 * squash,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.45 * opacity),
    );
  }

  void _bars(Canvas canvas, Offset origin, double width, double opacity) {
    const heights = [0.35, 0.55, 0.72, 1.0];
    final barW = width / 6;
    final maxH = width * 1.1;
    for (var i = 0; i < heights.length; i++) {
      final bh = maxH * heights[i];
      final rect = Rect.fromLTWH(
        origin.dx + i * barW * 1.5,
        origin.dy - bh,
        barW,
        bh,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(barW / 2)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF67E8F9).withValues(alpha: 0.95 * opacity),
              const Color(0xFF8B5CF6).withValues(alpha: 0.75 * opacity),
            ],
          ).createShader(rect),
      );
      // Highlight down the left side of each bar.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            rect.left + barW * 0.18,
            rect.top + barW * 0.3,
            barW * 0.18,
            bh - barW * 0.6,
          ),
          Radius.circular(barW),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.35 * opacity),
      );
    }
    // Trend arrow over the bars.
    final start = Offset(origin.dx - barW * 0.4, origin.dy - maxH * 0.3);
    final end = Offset(origin.dx + barW * 5.6, origin.dy - maxH * 1.12);
    final arrow = Paint()
      ..color = Colors.white.withValues(alpha: 0.85 * opacity)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(start, end, arrow);
    final dir = (end - start) / (end - start).distance;
    final normal = Offset(-dir.dy, dir.dx);
    canvas.drawPath(
      Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(
          end.dx - dir.dx * 12 + normal.dx * 7,
          end.dy - dir.dy * 12 + normal.dy * 7,
        )
        ..moveTo(end.dx, end.dy)
        ..lineTo(
          end.dx - dir.dx * 12 - normal.dx * 7,
          end.dy - dir.dy * 12 - normal.dy * 7,
        ),
      arrow,
    );
  }

  void _sphere(Canvas canvas, Offset c, double r, Color color, double o) {
    final rect = Rect.fromCircle(center: c, radius: r);
    final hsl = HSLColor.fromColor(color);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [
            hsl
                .withLightness((hsl.lightness + 0.25).clamp(0, 1))
                .toColor()
                .withValues(alpha: o),
            color.withValues(alpha: o),
            hsl
                .withLightness((hsl.lightness - 0.2).clamp(0, 1))
                .toColor()
                .withValues(alpha: o),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: c - Offset(r * 0.32, r * 0.4),
        width: r * 0.7,
        height: r * 0.38,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.5 * o),
    );
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.background != background ||
      old.accent != accent ||
      old.objects != objects ||
      old.dark != dark ||
      !identical(old.fields, fields);
}
