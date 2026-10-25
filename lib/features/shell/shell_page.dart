import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/motion/motion.dart';
import '../../core/motion/tab_transition_stack.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../shared/widgets/decor/ambient_background.dart';
import '../cards/cards_page.dart';
import '../home/home_controller.dart';
import '../home/home_page.dart';
import '../insights/insights_page.dart';
import '../profile/profile_page.dart';
import '../transactions/transactions_page.dart';
import 'app_tab.dart';
import 'glass_nav_bar.dart';
import 'launch_intro.dart';
import 'shell_controller.dart';

/// Hosts the five primary destinations over the ambient background. Uses a
/// floating glass bar on phones and a navigation rail on tablets and in
/// landscape.
class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  final controller = Get.find<ShellController>();

  // Keeps tab state alive when the layout switches between bar and rail
  // (e.g. on rotation).
  final _stackKey = GlobalKey();

  /// The launch intro plays once per app process (see [LaunchIntro.played]).
  late bool _showIntro;

  /// Tabs are mounted when the intro starts to reveal them, so their own
  /// entrance animations play in view rather than behind the intro.
  late bool _contentMounted;

  @override
  void initState() {
    super.initState();
    // Decide before marking the intro as played.
    _showIntro = !LaunchIntro.played && AppMotion.intro;
    _contentMounted = !_showIntro;
    LaunchIntro.played = true;
    // Start loading data while the intro plays.
    Get.find<HomeController>();
  }

  @override
  Widget build(BuildContext context) {
    final size = context.windowSize;
    if (_showIntro && AppMotion.reduced(context)) {
      _showIntro = false;
      _contentMounted = true;
    }

    return Obx(() {
      final tab = controller.current.value;
      final body = !_contentMounted
          ? const SizedBox.expand()
          : TabTransitionStack(
              key: _stackKey,
              index: tab.index,
              children: const [
                HomePage(),
                TransactionsPage(),
                CardsPage(),
                InsightsPage(),
                ProfilePage(),
              ],
            );

      final shell = PopScope(
        canPop: tab == AppTab.home,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) controller.handleBack();
        },
        child: size.isCompact
            ? Scaffold(
                // Content scrolls beneath the floating glass bar.
                extendBody: true,
                body: AmbientBackground(child: body),
                bottomNavigationBar: GlassNavBar(
                  current: tab,
                  onSelect: controller.select,
                ),
              )
            : Scaffold(
                body: AmbientBackground(
                  child: Row(
                    children: [
                      _Rail(
                        current: tab,
                        onSelect: controller.select,
                        extended: size == WindowSize.expanded,
                      ),
                      Expanded(child: body),
                    ],
                  ),
                ),
              ),
      );

      if (!_showIntro) return shell;
      return Stack(
        children: [
          shell,
          Positioned.fill(
            child: LaunchIntro(
              onReveal: () => setState(() => _contentMounted = true),
              onDone: () => setState(() => _showIntro = false),
            ),
          ),
        ],
      );
    });
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.current,
    required this.onSelect,
    required this.extended,
  });

  final AppTab current;
  final ValueChanged<AppTab> onSelect;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    // On short screens (phone landscape) the rail scrolls instead of
    // overflowing.
    // The background extends under the display cutout and system bars.
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: dark ? 0.55 : 0.7),
        border: Border(right: BorderSide(color: context.colors.outlineVariant)),
      ),
      child: SafeArea(
        right: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(child: _rail(context)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rail(BuildContext context) {
    return NavigationRail(
      backgroundColor: Colors.transparent,
      extended: extended,
      minExtendedWidth: 220,
      selectedIndex: current.index,
      onDestinationSelected: (i) => onSelect(AppTab.values[i]),
      labelType: extended
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: _BrandMark(showName: extended),
      ),
      destinations: [
        for (final t in AppTab.values)
          NavigationRailDestination(
            icon: Icon(t.icon),
            selectedIcon: Icon(t.selectedIcon),
            label: Text(t.label),
          ),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.showName});

  final bool showName;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: context.fin.heroGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.waves_rounded, color: Colors.white, size: 22),
    );
    if (!showName) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 12),
        Text('FinFlow', style: context.text.titleLarge),
      ],
    );
  }
}
