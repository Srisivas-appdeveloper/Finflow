import 'package:flutter/material.dart';

import 'motion.dart';

/// Fades and slides [child] into place once, when first built.
///
/// Use [index] to stagger a group of siblings. The delay is folded into the
/// animation itself (no timers), so it is safe in tests and when the widget
/// is disposed early.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = const Offset(0, 16),
    this.duration = AppMotion.long,
    this.stagger = AppMotion.staggerStep,
  });

  final Widget child;
  final int index;
  final Offset offset;
  final Duration duration;
  final Duration stagger;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    final delay = widget.stagger * widget.index.clamp(0, 12);
    final total = delay + widget.duration;
    _controller = AnimationController(vsync: this, duration: total);
    if (total == Duration.zero) _controller.value = 1;
    final start = total == Duration.zero
        ? 0.0
        : delay.inMicroseconds / total.inMicroseconds;
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1, curve: AppMotion.decelerate),
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Set when a glass panel inside claims the reveal: glass must not sit in
  /// an opacity layer (its backdrop blur would have nothing to read), so it
  /// "frosts in" by itself instead.
  bool _glassOwned = false;

  @override
  Widget build(BuildContext context) {
    return RevealScope(
      progress: _progress,
      onClaim: () => _glassOwned = true,
      child: AnimatedBuilder(
        animation: _progress,
        child: widget.child,
        builder: (context, child) {
          final t = _progress.value;
          // Opacity at 1.0 adds no layer; the structure stays constant so
          // the child's state is preserved.
          return Opacity(
            opacity: _glassOwned ? 1 : t,
            child: Transform.translate(
              offset: widget.offset * (1 - t),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

/// Exposes an entrance animation's progress to descendants that animate
/// their own appearance (see [Glass]).
class RevealScope extends InheritedWidget {
  const RevealScope({
    super.key,
    required this.progress,
    required this.onClaim,
    required super.child,
  });

  final Animation<double> progress;

  /// Called by a descendant that takes over fading itself.
  final VoidCallback onClaim;

  /// The nearest reveal progress, claiming it for the caller.
  static Animation<double>? claim(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RevealScope>();
    scope?.onClaim();
    return scope?.progress;
  }

  @override
  bool updateShouldNotify(RevealScope old) => old.progress != progress;
}

/// Gives tappable surfaces a subtle press-down scale.
///
/// Uses a raw [Listener], so it never competes with the child's own gesture
/// recognisers (an [InkWell] inside still receives the tap).
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.scale = 0.97,
    this.enabled = true,
  });

  final Widget child;
  final double scale;
  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _set(bool value) {
    // A tap that navigates away can dispose this widget before pointer-up.
    if (!mounted || !widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: AppMotion.of(context, AppMotion.short),
        curve: AppMotion.standard,
        child: widget.child,
      ),
    );
  }
}

/// Runs a one-shot 0→1 animation after [delay] and hands the curved value to
/// [builder]. Use it to stagger bars, fills and reveals.
///
/// If [value] changes later, animates from the current progress towards it
/// (so a bar can grow or shrink when data updates).
class DelayedAnimationBuilder extends StatefulWidget {
  const DelayedAnimationBuilder({
    super.key,
    required this.builder,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 900),
    this.curve = AppMotion.silk,
    this.value = 1,
    this.child,
  });

  final Widget Function(BuildContext context, double t, Widget? child) builder;
  final Duration delay;
  final Duration duration;
  final Curve curve;

  /// Target value, usually a fraction such as a bar's length.
  final double value;
  final Widget? child;

  @override
  State<DelayedAnimationBuilder> createState() =>
      _DelayedAnimationBuilderState();
}

class _DelayedAnimationBuilderState extends State<DelayedAnimationBuilder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _from = 0;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + widget.duration;
    _controller = AnimationController(vsync: this, duration: total);
    _animation = _curved(widget.delay.inMicroseconds / total.inMicroseconds);
  }

  Animation<double> _curved(double start) =>
      Tween<double>(begin: _from, end: widget.value).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, 1, curve: widget.curve),
        ),
      );

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
  void didUpdateWidget(DelayedAnimationBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _from = _animation.value;
      _controller.duration = widget.duration;
      _animation = _curved(0);
      _controller.forward(from: AppMotion.reduced(context) ? 1 : 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) =>
          widget.builder(context, _animation.value, child),
    );
  }
}

/// Editorial text reveal: [child] rises into view from behind an invisible
/// line at its own baseline, as on luxury print and web layouts.
class MaskReveal extends StatelessWidget {
  const MaskReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 1000),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return DelayedAnimationBuilder(
      delay: delay,
      duration: duration,
      curve: AppMotion.silk,
      child: child,
      builder: (context, t, child) => ClipRect(
        clipper: const _HorizontalBleedClipper(),
        child: FractionalTranslation(
          translation: Offset(0, 1 - t),
          child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
        ),
      ),
    );
  }
}

/// Clips vertically only, so italic overhangs aren't cut at the sides.
class _HorizontalBleedClipper extends CustomClipper<Rect> {
  const _HorizontalBleedClipper();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-24, -2, size.width + 24, size.height + 2);

  @override
  bool shouldReclip(_HorizontalBleedClipper oldClipper) => false;
}
