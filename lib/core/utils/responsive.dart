import 'package:flutter/widgets.dart';

import '../theme/app_spacing.dart';

/// Material 3 window size classes.
enum WindowSize {
  compact,
  medium,
  expanded;

  static WindowSize fromWidth(double width) {
    if (width >= 840) return WindowSize.expanded;
    if (width >= 600) return WindowSize.medium;
    return WindowSize.compact;
  }

  bool get isCompact => this == WindowSize.compact;
}

extension ResponsiveContext on BuildContext {
  WindowSize get windowSize =>
      WindowSize.fromWidth(MediaQuery.sizeOf(this).width);
}

/// Centres content and caps its width so long lines and stretched cards
/// don't appear on tablets and landscape phones.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 760});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Horizontal padding for page content, centred and capped at [maxWidth].
/// Usable both inside and outside slivers.
EdgeInsets pageInsets(BuildContext context, {double maxWidth = 760}) {
  final width = MediaQuery.sizeOf(context).width;
  final extra = width > maxWidth ? (width - maxWidth) / 2 : 0.0;
  return EdgeInsets.symmetric(horizontal: AppSpacing.gutter + extra);
}
