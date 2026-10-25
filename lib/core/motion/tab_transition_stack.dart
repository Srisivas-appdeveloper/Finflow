import 'package:flutter/material.dart';

import '../../shared/widgets/decor/ambient_background.dart';
import 'motion.dart';

/// Shows one of [children] at a time and slides between them like pages:
/// moving to a higher index slides the new tab in from the trailing edge,
/// moving to a lower index from the leading edge. The shared background
/// behind the tabs stays still, which reads as depth.
///
/// Only transforms are used (no opacity or blur layers): glass panels
/// inside the tabs keep blurring the real background throughout, and the
/// transition costs almost nothing to render.
///
/// Every child stays mounted so scroll positions and controller state
/// survive tab switches. Inactive children are offstage, have tickers
/// paused, and have hero animations disabled.
class TabTransitionStack extends StatefulWidget {
  const TabTransitionStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 460),
  });

  final int index;
  final List<Widget> children;
  final Duration duration;

  @override
  State<TabTransitionStack> createState() => _TabTransitionStackState();
}

class _TabTransitionStackState extends State<TabTransitionStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration, value: 1)
        // Scroll views inside the tabs are cached layers that the slide
        // moves without repainting; glass backdrop slices must re-align.
        ..addListener(BackdropReposition.instance.ping);
  late int _current = widget.index;
  int? _previous;
  double _direction = 1;

  @override
  void didUpdateWidget(TabTransitionStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != _current) {
      _previous = _current;
      _direction = widget.index > _current ? 1 : -1;
      _current = widget.index;
      _controller.duration = AppMotion.of(context, widget.duration);
      _controller.forward(from: 0).whenCompleteOrCancel(() {
        if (mounted) setState(() => _previous = null);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final sign = _direction * (rtl ? -1 : 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = AppMotion.silk.transform(_controller.value);
            final animating = _controller.isAnimating;
            return Stack(
              fit: StackFit.expand,
              children: [
                for (var i = 0; i < widget.children.length; i++)
                  _slot(
                    index: i,
                    visible: i == _current || (animating && i == _previous),
                    isCurrent: i == _current,
                    // Incoming from one full width away; outgoing leaves the
                    // other way, together, like a pager.
                    dx: i == _current
                        ? sign * width * (1 - t)
                        : -sign * width * t,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // The widget structure must be identical for every slot and every frame so
  // that Flutter keeps each child's element (and state) alive.
  Widget _slot({
    required int index,
    required bool visible,
    required bool isCurrent,
    required double dx,
  }) {
    return KeyedSubtree(
      key: ValueKey(index),
      child: Offstage(
        offstage: !visible,
        child: TickerMode(
          enabled: visible,
          child: HeroMode(
            enabled: isCurrent,
            child: IgnorePointer(
              ignoring: !isCurrent,
              child: ExcludeSemantics(
                excluding: !isCurrent,
                child: Transform.translate(
                  offset: Offset(visible ? dx : 0, 0),
                  child: widget.children[index],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
