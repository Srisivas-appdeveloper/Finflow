import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/motion/animated_widgets.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/decor/ambient_background.dart';
import '../shell/launch_intro.dart';
import 'onboarding_scenes.dart';

/// First-run introduction: three animated "clips" that play like short
/// videos. Story-style bars at the top fill and auto-advance; swiping pauses
/// them. Finishing (or skipping) is remembered on this device.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _Slide {
  const _Slide(this.eyebrow, this.title, this.body, this.glow);
  final String eyebrow;
  final String title;
  final String body;
  final Color glow;
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  static const _slides = [
    _Slide(
      '01 · TRACK',
      'Every rupee,\nbeautifully clear',
      'See all your spending and income in one calm, colourful place.',
      Color(0xFF8B5CF6),
    ),
    _Slide(
      '02 · UNDERSTAND',
      'Know where\nit all goes',
      'Categories, trends and daily patterns, obvious at a glance.',
      Color(0xFF06B6D4),
    ),
    _Slide(
      '03 · PRIVATE',
      'Yours, and\nonly yours',
      'Your data stays on this device. Nothing is shared without your '
          'permission.',
      Color(0xFFEC4899),
    ),
  ];

  final _pages = PageController();
  double _page = 0;
  int _index = 0;
  bool _dragging = false;
  bool _leaving = false;

  /// Fills the current story bar; advances when full.
  late final AnimationController _story = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..addStatusListener(_onStoryStatus);

  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  late bool _showIntro;

  @override
  void initState() {
    super.initState();
    _showIntro = !LaunchIntro.played && AppMotion.intro;
    LaunchIntro.played = true;
    _pages.addListener(() => setState(() => _page = _pages.page ?? 0));
    // Inherited settings (reduced motion) are only readable after init.
    if (!_showIntro) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startStory());
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _story.dispose();
    _exit.dispose();
    super.dispose();
  }

  void _startStory() {
    if (!mounted || AppMotion.reduced(context) || !AppMotion.intro) return;
    _story.forward(from: 0);
  }

  void _onStoryStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        !_dragging &&
        _index < _slides.length - 1) {
      _goTo(_index + 1);
    }
  }

  void _goTo(int index) {
    _pages.animateToPage(
      index,
      duration: AppMotion.of(context, const Duration(milliseconds: 700)),
      curve: AppMotion.silk,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _index = index);
    _startStory();
  }

  Future<void> _finish() async {
    if (_leaving) return;
    _leaving = true;
    _story.stop();
    final animate = !AppMotion.reduced(context);
    // Replayed from Profile: the app is underneath, so just return to it.
    // Replacing the whole stack would rebuild the shell, and GetX would then
    // dispose the new screens' controllers along with the old ones.
    final replay = Navigator.of(context).canPop();
    await Get.find<SettingsRepository>().setOnboardingComplete(true);
    if (animate) await _exit.forward();
    if (replay) {
      Get.back<void>();
    } else {
      Get.offAllNamed<void>(AppRoutes.shell);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _slides.length - 1;
    final glow = _glowAt(_page);

    final content = SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.sm,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _StoryBars(story: _story, index: _index),
                ),
                const SizedBox(width: AppSpacing.sm),
                TextButton(onPressed: _finish, child: const Text('Skip')),
              ],
            ),
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollStartNotification && n.dragDetails != null) {
                  _dragging = true;
                  _story.stop();
                } else if (n is ScrollEndNotification && _dragging) {
                  _dragging = false;
                  if (!_story.isAnimating && !_story.isCompleted) {
                    _story.forward();
                  }
                }
                return false;
              },
              child: PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, i) => _SlideView(
                  slide: _slides[i],
                  index: i,
                  offset: _page - i,
                  active: i == _index && !_showIntro,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Row(
              children: [
                _LiquidDots(page: _page, count: _slides.length),
                const Spacer(),
                SizedBox(
                  width: 170,
                  child: AppButton(
                    label: last ? 'Get started' : 'Next',
                    icon: last
                        ? Icons.rocket_launch_rounded
                        : Icons.arrow_forward_rounded,
                    expand: true,
                    onPressed: last ? _finish : () => _goTo(_index + 1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      body: AmbientBackground(
        objects: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Per-page coloured light, blending as you swipe.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.35),
                    radius: 0.9,
                    colors: [
                      glow.withValues(alpha: 0.35),
                      glow.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _exit,
              child: content,
              builder: (context, child) {
                final e = Curves.easeInCubic.transform(_exit.value);
                return Opacity(
                  opacity: 1 - e,
                  child: Transform.scale(scale: 1 + 0.12 * e, child: child),
                );
              },
            ),
            if (_showIntro)
              Positioned.fill(
                child: LaunchIntro(
                  onReveal: _startStory,
                  onDone: () => setState(() => _showIntro = false),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _glowAt(double page) {
    final i = page.floor().clamp(0, _slides.length - 1);
    final j = math.min(i + 1, _slides.length - 1);
    return Color.lerp(_slides[i].glow, _slides[j].glow, page - i)!;
  }
}

/// One onboarding page: the animated scene above editorial text. The scene
/// and text move at different speeds while swiping (parallax).
class _SlideView extends StatelessWidget {
  const _SlideView({
    required this.slide,
    required this.index,
    required this.offset,
    required this.active,
  });

  final _Slide slide;
  final int index;

  /// Signed distance from the settled position, in pages.
  final double offset;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final fin = context.fin;
    final scene = switch (index) {
      0 => TrackScene(active: active),
      1 => UnderstandScene(active: active),
      _ => PrivateScene(active: active),
    };
    final fade = (1 - offset.abs() * 1.4).clamp(0.0, 1.0);

    final sceneView = Transform.translate(
      // The scene lags behind the swipe for depth.
      offset: Offset(offset * width * 0.35, 0),
      child: Transform.scale(
        scale: 1 - offset.abs() * 0.12,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: scene,
        ),
      ),
    );

    final text = Opacity(
      opacity: fade,
      child: Transform.translate(
        // Text leads the swipe slightly.
        offset: Offset(-offset * width * 0.15, 0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          // On short screens the block shrinks to fit rather than overflow.
          child: LayoutBuilder(
            builder: (context, constraints) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MaskReveal(
                      child: Text(
                        slide.eyebrow,
                        style: context.text.eyebrow.copyWith(color: fin.accent),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    MaskReveal(
                      delay: const Duration(milliseconds: 120),
                      child: ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (r) => LinearGradient(
                          colors: [
                            context.colors.onSurface,
                            context.colors.onSurface,
                            fin.accent,
                          ],
                          stops: const [0, 0.55, 1],
                        ).createShader(r),
                        child: Text(
                          slide.title,
                          style: context.text.headlineLarge!.copyWith(
                            fontSize: 34,
                            height: 1.08,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FadeSlideIn(
                      index: 4,
                      child: Text(
                        slide.body,
                        style: context.text.bodyLarge?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Landscape: scene and text side by side.
        if (constraints.maxWidth > constraints.maxHeight * 1.2) {
          return Row(
            children: [
              Expanded(child: sceneView),
              Expanded(child: Center(child: text)),
            ],
          );
        }
        return Column(
          children: [
            Expanded(flex: 6, child: sceneView),
            Expanded(flex: 4, child: text),
          ],
        );
      },
    );
  }
}

/// Instagram-style progress segments; the current one fills with [story].
class _StoryBars extends StatelessWidget {
  const _StoryBars({required this.story, required this.index});

  final Animation<double> story;
  final int index;

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return AnimatedBuilder(
      animation: story,
      builder: (context, _) => Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  height: 4,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ColoredBox(
                          color: context.colors.onSurface.withValues(
                            alpha: 0.12,
                          ),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: i < index
                            ? 1
                            : i == index
                            ? story.value
                            : 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: fin.accentGradient,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Page dots; the active one stretches into a gradient pill and the change
/// tracks the swipe continuously.
class _LiquidDots extends StatelessWidget {
  const _LiquidDots({required this.page, required this.count});

  final double page;
  final int count;

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          Builder(
            builder: (context) {
              final near = (1 - (page - i).abs()).clamp(0.0, 1.0);
              return Container(
                margin: const EdgeInsets.only(right: 6),
                width: 8 + 22 * near,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: near > 0.05 ? fin.accentGradient : null,
                  color: near > 0.05
                      ? null
                      : context.colors.onSurface.withValues(alpha: 0.2),
                ),
              );
            },
          ),
      ],
    );
  }
}
