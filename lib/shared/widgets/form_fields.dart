import 'package:flutter/cupertino.dart'
    show
        CupertinoDatePicker,
        CupertinoDatePickerMode,
        CupertinoTextThemeData,
        CupertinoTheme,
        CupertinoThemeData;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/motion/animated_widgets.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/formatters.dart';
import 'app_bottom_sheet.dart';
import 'app_button.dart';
import 'selection.dart';

/// Labelled group of form controls.
class FormSection extends StatelessWidget {
  const FormSection({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label.toUpperCase(),
            style: context.text.eyebrow.copyWith(color: context.fin.accent),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// A glass field showing a date (and optionally a time). Each part opens
/// its own sheet: a calendar for the date, a scroll wheel for the time.
/// With [withTime], quick "Today" and "Yesterday" chips sit underneath.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.withTime = false,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final bool withTime;
  final DateTime? firstDate;
  final DateTime? lastDate;

  DateTime get _first => firstDate ?? DateTime(2000);
  DateTime get _last => lastDate ?? DateTime(2100);

  static DateTime _now() => Get.isRegistered<AppClock>()
      ? Get.find<AppClock>().now()
      : DateTime.now();

  /// [day]'s date with [value]'s time of day.
  DateTime _onDay(DateTime day) =>
      DateTime(day.year, day.month, day.day, value.hour, value.minute);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pickDate(BuildContext context) async {
    final date = await AppBottomSheet.show<DateTime>(
      context,
      builder: (_) => _DateSheet(
        title: withTime ? 'Date' : label,
        initial: value.isBefore(_first)
            ? _first
            : value.isAfter(_last)
            ? _last
            : value,
        first: _first,
        last: _last,
      ),
    );
    if (date != null) onChanged(_onDay(date));
  }

  Future<void> _pickTime(BuildContext context) async {
    final time = await AppBottomSheet.show<DateTime>(
      context,
      builder: (_) => _TimeSheet(initial: value, now: _now()),
    );
    if (time != null) {
      onChanged(
        DateTime(value.year, value.month, value.day, time.hour, time.minute),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    final fin = context.fin;
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final relative = _sameDay(value, today)
        ? 'Today'
        : _sameDay(value, yesterday)
        ? 'Yesterday'
        : null;

    final field = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadii.control,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: fin.glassTint,
        ),
        border: Border.all(color: fin.glassRim),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: _FieldPart(
                icon: Icons.calendar_month_rounded,
                caption: withTime ? (relative ?? 'Date') : label,
                text: withTime ? f.fullDate(value) : _dateText(f, relative),
                semanticLabel:
                    '${withTime ? 'Date' : label}, ${f.fullDate(value)}',
                onTap: () => _pickDate(context),
              ),
            ),
            if (withTime) ...[
              VerticalDivider(
                width: 1,
                indent: AppSpacing.md,
                endIndent: AppSpacing.md,
                color: fin.hairline,
              ),
              Expanded(
                flex: 2,
                child: _FieldPart(
                  icon: Icons.schedule_rounded,
                  caption: 'Time',
                  text: f.time(value),
                  semanticLabel: 'Time, ${f.time(value)}',
                  onTap: () => _pickTime(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (!withTime) return field;
    final canYesterday = !yesterday.isBefore(
      DateTime(_first.year, _first.month, _first.day),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            GlassChip(
              label: 'Today',
              selected: relative == 'Today',
              onTap: () => onChanged(_onDay(today)),
            ),
            if (canYesterday)
              GlassChip(
                label: 'Yesterday',
                selected: relative == 'Yesterday',
                onTap: () => onChanged(_onDay(yesterday)),
              ),
            GlassChip(
              label: relative == null ? f.dayMonth(value) : 'Other day',
              icon: Icons.calendar_month_rounded,
              selected: relative == null,
              onTap: () => _pickDate(context),
            ),
          ],
        ),
      ],
    );
  }

  String _dateText(Formatters f, String? relative) =>
      relative == null ? f.fullDate(value) : '$relative · ${f.dayMonth(value)}';
}

/// One tappable half of [DateField]: icon, small caption and value.
class _FieldPart extends StatelessWidget {
  const _FieldPart({
    required this.icon,
    required this.caption,
    required this.text,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String caption;
  final String text;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: PressableScale(
        scale: 0.97,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: AppRadii.control,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md - 2,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: fin.accent.withValues(alpha: 0.14),
                    ),
                    child: Icon(icon, size: 18, color: fin.accent),
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          caption.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.eyebrow.copyWith(
                            color: fin.textMuted,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            text,
                            maxLines: 1,
                            style: context.text.titleSmall?.tabular,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Calendar in a glass sheet. Pops with the chosen day.
class _DateSheet extends StatefulWidget {
  const _DateSheet({
    required this.title,
    required this.initial,
    required this.first,
    required this.last,
  });

  final String title;
  final DateTime initial;
  final DateTime first;
  final DateTime last;

  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  late DateTime _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    return AppSheet(
      title: widget.title,
      subtitle: f.longDate(_selected),
      icon: Icons.calendar_month_rounded,
      body: _MonthCalendar(
        selected: _selected,
        first: widget.first,
        last: widget.last,
        today: DateField._now(),
        onSelected: (d) => setState(() => _selected = d),
      ),
      actions: AppButton(
        label: 'Set date',
        icon: Icons.check_rounded,
        expand: true,
        onPressed: () => Navigator.of(context).pop(_selected),
      ),
    );
  }
}

/// Month grid with arrows to change month. The selected day is filled
/// with the accent gradient; today has an accent ring.
class _MonthCalendar extends StatefulWidget {
  const _MonthCalendar({
    required this.selected,
    required this.first,
    required this.last,
    required this.today,
    required this.onSelected,
  });

  final DateTime selected;
  final DateTime first;
  final DateTime last;
  final DateTime today;
  final ValueChanged<DateTime> onSelected;

  @override
  State<_MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<_MonthCalendar> {
  late DateTime _month = DateTime(widget.selected.year, widget.selected.month);

  /// +1 when moving forward, -1 back; sets the slide direction.
  var _direction = 1;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get _canGoBack =>
      _month.isAfter(DateTime(widget.first.year, widget.first.month));
  bool get _canGoForward =>
      _month.isBefore(DateTime(widget.last.year, widget.last.month));

  void _shift(int months) => setState(() {
    _direction = months.sign;
    _month = DateTime(_month.year, _month.month + months);
  });

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    final fin = context.fin;
    final l10n = MaterialLocalizations.of(context);
    final firstWeekday = l10n.firstDayOfWeekIndex; // 0 = Sunday
    final weekdays = [
      for (var i = 0; i < 7; i++) l10n.narrowWeekdays[(firstWeekday + i) % 7],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: AppMotion.of(context, AppMotion.short),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.centerLeft,
                  children: [...previous, ?current],
                ),
                child: Text(
                  f.monthYear(_month),
                  key: ValueKey(_month),
                  style: context.text.titleMedium,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Previous month',
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: _canGoBack ? () => _shift(-1) : null,
            ),
            IconButton(
              tooltip: 'Next month',
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: _canGoForward ? () => _shift(1) : null,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ExcludeSemantics(
          child: Row(
            children: [
              for (final w in weekdays)
                Expanded(
                  child: Text(
                    w,
                    textAlign: TextAlign.center,
                    style: context.text.labelMedium?.copyWith(
                      color: fin.textMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AnimatedSwitcher(
          duration: AppMotion.of(context, AppMotion.medium),
          switchInCurve: AppMotion.decelerate,
          transitionBuilder: (child, animation) {
            final incoming = child.key == ValueKey(_month);
            final dx = (incoming ? 0.25 : -0.25) * _direction;
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: Offset(dx, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          layoutBuilder: (current, previous) =>
              Stack(children: [...previous, ?current]),
          child: _grid(context, firstWeekday),
        ),
      ],
    );
  }

  Widget _grid(BuildContext context, int firstWeekday) {
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    // Blank cells before the 1st, given the locale's first day of week.
    final lead = (_month.weekday % 7 - firstWeekday + 7) % 7;
    final first = _day(widget.first);
    final last = _day(widget.last);
    final selected = _day(widget.selected);
    final today = _day(widget.today);

    return GridView.count(
      key: ValueKey(_month),
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        for (var i = 0; i < lead; i++) const SizedBox.shrink(),
        for (final date in [
          for (var d = 1; d <= days; d++)
            DateTime(_month.year, _month.month, d),
        ])
          _DayCell(
            date: date,
            enabled: !date.isBefore(first) && !date.isAfter(last),
            selected: date == selected,
            today: date == today,
            onTap: widget.onSelected,
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.enabled,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final DateTime date;
  final bool enabled;
  final bool selected;
  final bool today;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: Get.find<Formatters>().longDate(date),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onTap(date) : null,
        child: Center(
          child: AnimatedContainer(
            duration: AppMotion.of(context, AppMotion.short),
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: selected ? fin.accentGradient : null,
              border: today && !selected
                  ? Border.all(color: fin.accent, width: 1.4)
                  : null,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: fin.accent.withValues(alpha: 0.45),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              '${date.day}',
              style: context.text.bodyLarge?.tabular.copyWith(
                fontWeight: selected || today
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: selected
                    ? Colors.white
                    : !enabled
                    ? fin.textMuted.withValues(alpha: 0.4)
                    : today
                    ? fin.accent
                    : context.colors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hour and minute wheels in a glass sheet. Pops with a [DateTime] whose
/// hour and minute are the chosen time.
class _TimeSheet extends StatefulWidget {
  const _TimeSheet({required this.initial, required this.now});

  final DateTime initial;
  final DateTime now;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  late DateTime _selected = widget.initial;

  /// Rebuilds the wheels when "Now" jumps them.
  var _wheelKey = 0;

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    final fin = context.fin;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AppSheet(
      title: 'Time',
      subtitle: f.time(_selected),
      icon: Icons.schedule_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 200,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: context.text.headlineSmall?.tabular
                      .copyWith(color: context.colors.onSurface, fontSize: 22),
                ),
              ),
              child: CupertinoDatePicker(
                key: ValueKey(_wheelKey),
                mode: CupertinoDatePickerMode.time,
                initialDateTime: _selected,
                use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
                backgroundColor: Colors.transparent,
                selectionOverlayBuilder:
                    (context, {required columnCount, required selectedIndex}) {
                      // One accent band across all wheels.
                      final first = selectedIndex == 0;
                      final last = selectedIndex == columnCount - 1;
                      return Container(
                        margin: EdgeInsets.only(
                          left: first ? AppSpacing.sm : 0,
                          right: last ? AppSpacing.sm : 0,
                        ),
                        decoration: BoxDecoration(
                          color: fin.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.horizontal(
                            left: first
                                ? const Radius.circular(AppRadii.md)
                                : Radius.zero,
                            right: last
                                ? const Radius.circular(AppRadii.md)
                                : Radius.zero,
                          ),
                        ),
                      );
                    },
                onDateTimeChanged: (t) => setState(() => _selected = t),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: GlassChip(
              label: 'Now',
              icon: Icons.bolt_rounded,
              selected:
                  _selected.hour == widget.now.hour &&
                  _selected.minute == widget.now.minute,
              onTap: () => setState(() {
                _selected = widget.now;
                _wheelKey++;
              }),
            ),
          ),
        ],
      ),
      actions: AppButton(
        label: 'Set time',
        icon: Icons.check_rounded,
        expand: true,
        onPressed: () => Navigator.of(context).pop(_selected),
      ),
    );
  }
}

/// Picker for a day of the month (1-28), used for statement and due days.
class DayOfMonthField extends StatelessWidget {
  const DayOfMonthField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      menuMaxHeight: 320,
      borderRadius: AppRadii.control,
      dropdownColor: context.colors.surface,
      icon: Icon(Icons.expand_more_rounded, color: context.fin.textMuted),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_today_rounded),
      ),
      items: [
        for (var d = 1; d <= 28; d++)
          DropdownMenuItem(value: d, child: Text(_ordinal(d))),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  static String _ordinal(int d) {
    if (d >= 11 && d <= 13) return '${d}th';
    return switch (d % 10) {
      1 => '${d}st',
      2 => '${d}nd',
      3 => '${d}rd',
      _ => '${d}th',
    };
  }
}
