import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'motion.dart';

/// Route transitions for GetX pages.
///
/// Every transition is written in terms of two animations:
/// * `animation` drives this page entering (forward) and leaving on pop
///   (reverse).
/// * `secondaryAnimation` drives this page being covered by a new page
///   (forward) and revealed again when that page pops (reverse).
///
/// Because pop simply runs both animations in reverse, each transition is
/// symmetric by construction: back navigation mirrors forward navigation.
abstract final class AppTransitions {
  /// Horizontal shared-axis: for hierarchical navigation (list -> details).
  static final CustomTransition sharedAxis = SharedAxisPageTransition();

  /// Fade-through: for switching between unrelated top-level content.
  static final CustomTransition fadeThrough = FadeThroughPageTransition();

  /// Slide over: the new page slides in from the trailing edge while the
  /// page beneath drifts back and dims. Transforms and a tint only, so it
  /// stays smooth even over glass-heavy screens.
  static final CustomTransition slideOver = SlideOverPageTransition();

  /// Rise from the bottom: for focused, task-style pages.
  static final CustomTransition slideUp = SlideUpPageTransition();
}

/// Base class that handles the common details: reduced motion and an opaque
/// backdrop so the page behind never shows through mid-transition.
abstract class _AppPageTransition extends CustomTransition {
  @override
  Widget buildTransition(
    BuildContext context,
    Curve? curve,
    Alignment? alignment,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduced(context)) return child;
    return build(context, animation, secondaryAnimation, child);
  }

  Widget build(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  );
}

/// Applies [AppMotion.silk] so motion always starts fast and glides to rest:
/// when an animation runs in reverse (back navigation) the curve is mirrored
/// in time, so going back feels as smooth as going forward.
double _silk(Animation<double> a) => a.status == AnimationStatus.reverse
    ? AppMotion.silk.flipped.transform(a.value)
    : AppMotion.silk.transform(a.value);

/// Material shared-axis (X). The outgoing page slides left and fades out
/// during the first 30% of the transition; the incoming page slides in from
/// the right and fades in over the rest.
class SharedAxisPageTransition extends _AppPageTransition {
  SharedAxisPageTransition({this.distance = 48});

  /// Horizontal travel in logical pixels.
  final double distance;

  static const _fadeIn = Interval(0.3, 1, curve: AppMotion.decelerate);
  static const _fadeOut = Interval(0, 0.3, curve: AppMotion.accelerate);

  @override
  Widget build(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final sign = rtl ? -1.0 : 1.0;
    final background = Theme.of(context).scaffoldBackgroundColor;

    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondaryAnimation]),
      child: child,
      builder: (context, child) {
        final enter = _silk(animation);
        final exit = _silk(secondaryAnimation);
        final dx = sign * distance * ((1 - enter) - exit);
        return Opacity(
          opacity: _fadeIn.transform(animation.value),
          child: ColoredBox(
            color: background,
            child: Transform.translate(
              offset: Offset(dx, 0),
              child: Opacity(
                opacity: 1 - _fadeOut.transform(secondaryAnimation.value),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Material fade-through. The outgoing page fades out quickly, then the
/// incoming page fades in while scaling up from 92%.
class FadeThroughPageTransition extends _AppPageTransition {
  static const _fadeIn = Interval(0.35, 1, curve: AppMotion.decelerate);
  static const _fadeOut = Interval(0, 0.35, curve: AppMotion.accelerate);

  @override
  Widget build(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondaryAnimation]),
      child: child,
      builder: (context, child) {
        final t = _fadeIn.transform(animation.value);
        return Opacity(
          opacity: t,
          child: ColoredBox(
            color: background,
            child: Transform.scale(
              scale: 0.92 + 0.08 * t,
              child: Opacity(
                opacity: 1 - _fadeOut.transform(secondaryAnimation.value),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The incoming page rises from the bottom while the page beneath recedes
/// slightly, giving a sense of depth.
class SlideUpPageTransition extends _AppPageTransition {
  @override
  Widget build(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enter = CurvedAnimation(
      parent: animation,
      curve: AppMotion.emphasized,
      reverseCurve: AppMotion.emphasized.flipped,
    );
    final recede = CurvedAnimation(
      parent: secondaryAnimation,
      curve: AppMotion.standard,
    );
    return ScaleTransition(
      scale: Tween<double>(begin: 1, end: 0.95).animate(recede),
      child: FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0.6).animate(recede),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(enter),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0, 0.6, curve: AppMotion.decelerate),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class SlideOverPageTransition extends _AppPageTransition {
  @override
  Widget build(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final sign = rtl ? -1.0 : 1.0;
    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondaryAnimation]),
      child: child,
      builder: (context, child) {
        final width = MediaQuery.sizeOf(context).width;
        final enter = _silk(animation);
        final covered = _silk(secondaryAnimation);
        // Entering: from the trailing edge. Covered: drift back by a third.
        final dx = sign * width * ((1 - enter) - 0.3 * covered);
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              child!,
              // Dim the covered page with a plain tint (no layer).
              IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.32 * covered),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
