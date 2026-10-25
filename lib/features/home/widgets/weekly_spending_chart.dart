import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/motion/motion.dart';
import '../../../core/motion/rolling_number.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/money.dart';
import '../../../domain/entities/spending_summary.dart';
import '../../../shared/widgets/fin_card.dart';

/// Single-series bar chart of daily spending.
///
/// Bars rise one after another with a springy settle. Tap or drag across
/// the bars to select a day: the selection glides between bars and a value
/// bubble follows it. The most recent day is selected initially.
class WeeklySpendingCard extends StatefulWidget {
  const WeeklySpendingCard({
    super.key,
    required this.days,
    required this.total,
  });

  final List<DailySpend> days;
  final Money total;

  @override
  State<WeeklySpendingCard> createState() => _WeeklySpendingCardState();
}

class _WeeklySpendingCardState extends State<WeeklySpendingCard>
    with TickerProviderStateMixin {
  static const _chartHeight = 132.0;

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final AnimationController _select = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: 1,
  );

  late int _selected = widget.days.length - 1;
  late int _previous = _selected;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_intro.isDismissed) {
      if (AppMotion.reduced(context)) {
        _intro.value = 1;
      } else {
        _intro.forward();
      }
    }
  }

  @override
  void didUpdateWidget(WeeklySpendingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selected >= widget.days.length) {
      _selected = _previous = widget.days.length - 1;
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _select.dispose();
    super.dispose();
  }

  void _selectAt(double dx, double width) {
    final slot = width / widget.days.length;
    final i = (dx / slot).floor().clamp(0, widget.days.length - 1);
    if (i == _selected) return;
    HapticFeedback.selectionClick();
    setState(() {
      _previous = _selected;
      _selected = i;
    });
    _select.duration = AppMotion.of(context, const Duration(milliseconds: 380));
    _select.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    final fin = context.fin;
    final n = widget.days.length;
    final selected = widget.days[_selected];
    // Horizontal anchor of the selected bar, in Align coordinates.
    final anchorX = n == 1 ? 0.0 : -1 + 2 * (_selected + 0.5) / n;

    return FinCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LAST 7 DAYS',
                      style: context.text.eyebrow.copyWith(color: fin.accent),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Daily spending', style: context.text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Large totals shrink rather than overflow.
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: RollingNumberText(
                        f.money(widget.total),
                        delay: const Duration(milliseconds: 300),
                        style: context.text.titleMedium?.tabular,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text('Total spent', style: context.text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Value bubble that glides to the selected bar.
          AnimatedAlign(
            alignment: Alignment(anchorX, 0),
            duration: AppMotion.of(context, const Duration(milliseconds: 520)),
            curve: AppMotion.settle,
            child: _Bubble(
              label: f.relativeDay(selected.day, now: widget.days.last.day),
              value: f.money(selected.amount),
            ),
          ),
          AnimatedAlign(
            alignment: Alignment(anchorX, 0),
            duration: AppMotion.of(context, const Duration(milliseconds: 520)),
            curve: AppMotion.settle,
            child: Container(width: 1, height: 12, color: fin.accent),
          ),
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            label:
                'Daily spending chart. ${[for (final d in widget.days) '${f.weekdayShort(d.day)} ${f.money(d.amount)}'].join(', ')}',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _selectAt(d.localPosition.dx, width),
                  onHorizontalDragUpdate: (d) =>
                      _selectAt(d.localPosition.dx, width),
                  child: CustomPaint(
                    size: Size(width, _chartHeight),
                    painter: _BarsPainter(
                      values: [for (final d in widget.days) d.amount.minor],
                      selected: _selected,
                      previous: _previous,
                      intro: _intro,
                      select: _select,
                      bar: fin.chartBar,
                      barMuted: fin.chartBarMuted,
                      grid: fin.chartGrid,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ExcludeSemantics(
            child: Row(
              children: [
                for (var i = 0; i < n; i++)
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: AppMotion.of(context, AppMotion.medium),
                      style: context.text.labelSmall!.copyWith(
                        color: i == _selected
                            ? context.colors.onSurface
                            : fin.textMuted,
                        fontWeight: i == _selected
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                      child: Text(
                        f.weekdayInitial(widget.days[i].day),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fin = context.fin;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 3,
      ),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: fin.accent.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              '${label.toUpperCase()}  ',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.eyebrow.copyWith(color: fin.accent),
            ),
          ),
          Flexible(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: RollingNumberText(
                value,
                duration: const Duration(milliseconds: 700),
                stagger: const Duration(milliseconds: 25),
                style: context.text.labelLarge!.tabular.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.values,
    required this.selected,
    required this.previous,
    required this.intro,
    required this.select,
    required this.bar,
    required this.barMuted,
    required this.grid,
  }) : super(repaint: Listenable.merge([intro, select]));

  final List<int> values;
  final int selected;
  final int previous;
  final Animation<double> intro;
  final Animation<double> select;
  final Color bar;
  final Color barMuted;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = values.fold<int>(0, math.max);
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;

    // Leave headroom so the springy overshoot never clips.
    final usable = size.height * 0.88;
    // A single baseline: the bars carry the information.
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      gridPaint,
    );

    final n = values.length;
    final slot = size.width / n;
    final barWidth = math.min(16.0, slot * 0.34);
    final s = Curves.easeOutCubic.transform(select.value);

    for (var i = 0; i < n; i++) {
      // Each bar starts a little after the previous one.
      final start = i * 0.07;
      final grow = AppMotion.settle.transform(
        Interval(start, math.min(1, start + 0.55)).transform(intro.value),
      );
      final ratio = maxValue == 0 ? 0.0 : values[i] / maxValue;
      final target = values[i] == 0 ? 0.0 : math.max(4.0, usable * ratio);
      final h = target * grow;
      if (h <= 0.5) continue;

      final emphasis = i == selected
          ? s
          : i == previous
          ? 1 - s
          : 0.0;
      final color = Color.lerp(barMuted, bar, emphasis)!;
      final left = slot * i + (slot - barWidth) / 2;
      final rect = Rect.fromLTWH(left, size.height - h, barWidth, h);
      final rrect = RRect.fromRectAndCorners(
        rect,
        topLeft: Radius.circular(barWidth / 2),
        topRight: Radius.circular(barWidth / 2),
        bottomLeft: const Radius.circular(2),
        bottomRight: const Radius.circular(2),
      );

      if (emphasis > 0) {
        canvas.drawRRect(
          rrect.shift(const Offset(0, 6)),
          Paint()
            ..color = bar.withValues(alpha: 0.35 * emphasis)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
      }
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // Selected bar flows violet to cyan, like the accent.
            colors: [
              Color.lerp(color, const Color(0xFF22D3EE), 0.75 * emphasis)!,
              color,
            ],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.selected != selected ||
      old.previous != previous ||
      old.bar != bar ||
      old.barMuted != barMuted ||
      old.grid != grid ||
      !_listEquals(old.values, values);

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
