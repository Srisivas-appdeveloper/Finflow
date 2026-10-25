import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Shared motion tokens so every animation in the app feels related.
abstract final class AppMotion {
  static const Duration short = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration long = Duration(milliseconds: 420);
  static const Duration page = Duration(milliseconds: 460);

  /// Delay between items in a staggered entrance.
  static const Duration staggerStep = Duration(milliseconds: 45);

  static const Curve standard = Curves.easeInOutCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve decelerate = Curves.easeOutCubic;
  static const Curve accelerate = Curves.easeInCubic;

  /// Long, soft deceleration (exponential ease-out). Movement starts quickly
  /// and glides to rest, which reads as "silky".
  static const Curve silk = Cubic(0.16, 1, 0.3, 1);

  /// Gentle overshoot for things that land: bars, pills, digits.
  static const Curve settle = Cubic(0.34, 1.32, 0.64, 1);

  /// Under-damped spring: one small overshoot, then rest.
  static const Curve spring = SpringCurve();

  /// Whether continuous decorative animations run (background drift, card
  /// sway, floating orbs). Off by default for performance.
  static bool ambient = false;

  /// Whether the cold-start intro and onboarding clips play.
  static bool intro = true;

  /// Whether loading skeletons shimmer.
  static bool shimmer = true;

  /// True when the user asked the OS to reduce or remove animations.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// True when ambient animations should run in [context].
  static bool ambientIn(BuildContext context) => ambient && !reduced(context);

  /// [duration], or zero when animations are disabled system-wide.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}

/// A [Curve] sampled from a real spring simulation, so motion keeps its
/// physical feel while still fitting a fixed-duration animation.
class SpringCurve extends Curve {
  const SpringCurve({this.dampingRatio = 0.72, this.stiffness = 180});

  final double dampingRatio;
  final double stiffness;

  @override
  double transformInternal(double t) {
    final spring = SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: stiffness,
      ratio: dampingRatio,
    );
    final sim = SpringSimulation(spring, 0, 1, 0);
    // Map t to the simulation's settling window, then pin the end to 1.
    const window = 1.1;
    if (t >= 1) return 1;
    return sim.x(t * window);
  }
}
