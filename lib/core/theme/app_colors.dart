import 'package:flutter/material.dart';

/// Raw palette values. Widgets should not use these directly; read colors
/// from [ColorScheme] or [FinColors] so light and dark modes stay correct.
///
/// The look is modern glass: vivid colour fields and floating finance
/// objects behind frosted, tinted, rim-lit glass panels.
abstract final class AppPalette {
  // Accent: electric violet, flowing into blue and cyan.
  static const violet = Color(0xFF8B7CFF);
  static const violetDeep = Color(0xFF5B4BDB);
  static const blue = Color(0xFF3B82F6);
  static const cyan = Color(0xFF22D3EE);
  static const pink = Color(0xFFEC4899);
  static const amber = Color(0xFFF59E0B);

  // Dark (midnight)
  static const darkBackground = Color(0xFF060816);
  static const darkSurface = Color(0xFF12152B);
  static const darkSurfaceLow = Color(0xFF0C0F22);
  static const darkSurfaceHigh = Color(0xFF1A1E38);
  static const darkSurfaceHighest = Color(0xFF242949);
  static const darkOutline = Color(0xFF2E3358);
  static const darkOutlineVariant = Color(0xFF1C2040);
  static const darkTextPrimary = Color(0xFFF4F5FF);
  static const darkTextSecondary = Color(0xFFA9AECF);

  // Light (lavender mist)
  static const lightBackground = Color(0xFFEEF0FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceLow = Color(0xFFF4F5FD);
  static const lightSurfaceHigh = Color(0xFFE6E8F6);
  static const lightSurfaceHighest = Color(0xFFDCDFF1);
  static const lightOutline = Color(0xFFCBD0EA);
  static const lightOutlineVariant = Color(0xFFE1E4F4);
  static const lightTextPrimary = Color(0xFF0E1130);
  static const lightTextSecondary = Color(0xFF4A4F75);

  /// Categorical slots in fixed, colour-vision-deficiency-validated order.
  /// Assign by entity, never by rank.
  static const categoricalLight = <Color>[
    Color(0xFF2A78D6),
    Color(0xFFEB6834),
    Color(0xFF1BAF7A),
    Color(0xFFEDA100),
    Color(0xFFE87BA4),
    Color(0xFF008300),
    Color(0xFF6250D6),
    Color(0xFFE34948),
  ];

  static const categoricalDark = <Color>[
    Color(0xFF3987E5),
    Color(0xFFD95926),
    Color(0xFF199E70),
    Color(0xFFC98500),
    Color(0xFFD55181),
    Color(0xFF008300),
    Color(0xFF9085E9),
    Color(0xFFE66767),
  ];
}

/// Semantic colours that Material's [ColorScheme] does not cover.
@immutable
class FinColors extends ThemeExtension<FinColors> {
  const FinColors({
    required this.accent,
    required this.accentBright,
    required this.accentGradient,
    required this.hairline,
    required this.glassTint,
    required this.glassRim,
    required this.backdrop,
    required this.income,
    required this.incomeContainer,
    required this.expense,
    required this.pending,
    required this.pendingContainer,
    required this.failed,
    required this.failedContainer,
    required this.heroGradient,
    required this.onHero,
    required this.onHeroMuted,
    required this.textMuted,
    required this.chartBar,
    required this.chartBarMuted,
    required this.chartGrid,
    required this.categorical,
    required this.neutralCategory,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.glow,
  });

  /// Accent for text, icons and highlights; meets contrast in each mode.
  final Color accent;
  final Color accentBright;
  final Gradient accentGradient;

  /// Thin separators.
  final Color hairline;

  /// Glass fill: [top, bottom] of the tint gradient laid over the blur.
  final List<Color> glassTint;

  /// Bright rim light along glass edges.
  final Color glassRim;

  /// Colour fields painted behind everything.
  final List<Color> backdrop;

  final Color income;
  final Color incomeContainer;
  final Color expense;
  final Color pending;
  final Color pendingContainer;
  final Color failed;
  final Color failedContainer;

  /// Holographic fill of the month summary card (same in both modes).
  final Gradient heroGradient;
  final Color onHero;
  final Color onHeroMuted;
  final Color textMuted;

  final Color chartBar;
  final Color chartBarMuted;
  final Color chartGrid;
  final List<Color> categorical;
  final Color neutralCategory;

  final Color shimmerBase;
  final Color shimmerHighlight;

  /// Soft light used for halos around emblems.
  final Color glow;

  static const _holo = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6D28D9), Color(0xFFC026D3), Color(0xFFF97316)],
    stops: [0, 0.55, 1],
  );

  static const dark = FinColors(
    accent: AppPalette.violet,
    accentBright: Color(0xFFB4A9FF),
    accentGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppPalette.violet, AppPalette.blue, AppPalette.cyan],
    ),
    hairline: Color(0x1AFFFFFF),
    // Deep navy frosting: keeps text legible over bright backdrop objects.
    glassTint: [Color(0xA6222A4D), Color(0x99121833)],
    glassRim: Color(0x40FFFFFF),
    backdrop: [
      Color(0xFF7C3AED),
      Color(0xFF2563EB),
      Color(0xFF06B6D4),
      Color(0xFFDB2777),
      Color(0xFFF59E0B),
    ],
    income: Color(0xFF34D399),
    incomeContainer: Color(0xFF0F2E26),
    expense: AppPalette.darkTextPrimary,
    pending: Color(0xFFFBBF24),
    pendingContainer: Color(0xFF33270A),
    failed: Color(0xFFF87171),
    failedContainer: Color(0xFF3A1518),
    heroGradient: _holo,
    onHero: Colors.white,
    onHeroMuted: Color(0xCCFFFFFF),
    textMuted: Color(0xFF8A90B6),
    chartBar: AppPalette.violet,
    chartBarMuted: Color(0x33FFFFFF),
    chartGrid: Color(0x1FFFFFFF),
    categorical: AppPalette.categoricalDark,
    neutralCategory: Color(0xFF8A90B6),
    shimmerBase: Color(0x1FFFFFFF),
    shimmerHighlight: Color(0x38FFFFFF),
    glow: AppPalette.violet,
  );

  static const light = FinColors(
    accent: AppPalette.violetDeep,
    accentBright: AppPalette.violet,
    accentGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF6D5BEF), AppPalette.blue, Color(0xFF06B6D4)],
    ),
    hairline: Color(0x140E1130),
    glassTint: [Color(0xB3FFFFFF), Color(0x73FFFFFF)],
    glassRim: Color(0xF2FFFFFF),
    backdrop: [
      Color(0xFFA78BFA),
      Color(0xFF60A5FA),
      Color(0xFF22D3EE),
      Color(0xFFF472B6),
      Color(0xFFFBBF24),
    ],
    income: Color(0xFF047857),
    incomeContainer: Color(0xFFD1FAE5),
    expense: AppPalette.lightTextPrimary,
    pending: Color(0xFFB45309),
    pendingContainer: Color(0xFFFEF3C7),
    failed: Color(0xFFB91C1C),
    failedContainer: Color(0xFFFEE2E2),
    heroGradient: _holo,
    onHero: Colors.white,
    onHeroMuted: Color(0xD9FFFFFF),
    textMuted: Color(0xFF5F6489),
    chartBar: AppPalette.violetDeep,
    chartBarMuted: Color(0x3D5B4BDB),
    chartGrid: Color(0x1A0E1130),
    categorical: AppPalette.categoricalLight,
    neutralCategory: Color(0xFF6A6F94),
    shimmerBase: Color(0x80FFFFFF),
    shimmerHighlight: Color(0xE6FFFFFF),
    glow: AppPalette.violet,
  );

  @override
  FinColors copyWith({Color? income, Color? expense}) => FinColors(
    accent: accent,
    accentBright: accentBright,
    accentGradient: accentGradient,
    hairline: hairline,
    glassTint: glassTint,
    glassRim: glassRim,
    backdrop: backdrop,
    income: income ?? this.income,
    incomeContainer: incomeContainer,
    expense: expense ?? this.expense,
    pending: pending,
    pendingContainer: pendingContainer,
    failed: failed,
    failedContainer: failedContainer,
    heroGradient: heroGradient,
    onHero: onHero,
    onHeroMuted: onHeroMuted,
    textMuted: textMuted,
    chartBar: chartBar,
    chartBarMuted: chartBarMuted,
    chartGrid: chartGrid,
    categorical: categorical,
    neutralCategory: neutralCategory,
    shimmerBase: shimmerBase,
    shimmerHighlight: shimmerHighlight,
    glow: glow,
  );

  @override
  FinColors lerp(ThemeExtension<FinColors>? other, double t) {
    if (other is! FinColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<Color> cs(List<Color> a, List<Color> b) => [
      for (var i = 0; i < a.length; i++) c(a[i], b[i]),
    ];
    return FinColors(
      accent: c(accent, other.accent),
      accentBright: c(accentBright, other.accentBright),
      accentGradient: Gradient.lerp(accentGradient, other.accentGradient, t)!,
      hairline: c(hairline, other.hairline),
      glassTint: cs(glassTint, other.glassTint),
      glassRim: c(glassRim, other.glassRim),
      backdrop: cs(backdrop, other.backdrop),
      income: c(income, other.income),
      incomeContainer: c(incomeContainer, other.incomeContainer),
      expense: c(expense, other.expense),
      pending: c(pending, other.pending),
      pendingContainer: c(pendingContainer, other.pendingContainer),
      failed: c(failed, other.failed),
      failedContainer: c(failedContainer, other.failedContainer),
      heroGradient: Gradient.lerp(heroGradient, other.heroGradient, t)!,
      onHero: c(onHero, other.onHero),
      onHeroMuted: c(onHeroMuted, other.onHeroMuted),
      textMuted: c(textMuted, other.textMuted),
      chartBar: c(chartBar, other.chartBar),
      chartBarMuted: c(chartBarMuted, other.chartBarMuted),
      chartGrid: c(chartGrid, other.chartGrid),
      categorical: cs(categorical, other.categorical),
      neutralCategory: c(neutralCategory, other.neutralCategory),
      shimmerBase: c(shimmerBase, other.shimmerBase),
      shimmerHighlight: c(shimmerHighlight, other.shimmerHighlight),
      glow: c(glow, other.glow),
    );
  }
}

extension FinThemeContext on BuildContext {
  FinColors get fin => Theme.of(this).extension<FinColors>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}
