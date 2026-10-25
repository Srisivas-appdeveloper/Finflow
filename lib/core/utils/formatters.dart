import 'package:intl/intl.dart';

import '../../domain/entities/money.dart';

/// Locale-aware formatting for money and dates.
class Formatters {
  Formatters({this.locale = 'en_IN'});

  final String locale;
  final Map<String, NumberFormat> _currency = {};
  final Map<String, NumberFormat> _compact = {};

  /// `₹12,450.00`; negatives are prefixed with `−`. With [signed], positive
  /// amounts are also prefixed with `+`.
  String money(Money value, {bool signed = false}) {
    final format = _currency.putIfAbsent(
      value.currencyCode,
      () =>
          NumberFormat.simpleCurrency(locale: locale, name: value.currencyCode),
    );
    final text = format.format(value.abs().major);
    if (value.isNegative) return '−$text';
    if (signed && !value.isZero) return '+$text';
    return text;
  }

  String currencySymbol(String currencyCode) => NumberFormat.simpleCurrency(
    locale: locale,
    name: currencyCode,
  ).currencySymbol;

  /// `₹12.4K` style, for chart labels and tight spaces.
  String moneyCompact(Money value) {
    final format = _compact.putIfAbsent(
      value.currencyCode,
      () => NumberFormat.compactSimpleCurrency(
        locale: locale,
        name: value.currencyCode,
      ),
    );
    final text = format.format(value.abs().major);
    return value.isNegative ? '−$text' : text;
  }

  String percent(double fraction) =>
      NumberFormat.percentPattern(locale).format(fraction);

  static final _dayMonth = DateFormat('d MMM');
  static final _dayMonthYear = DateFormat('d MMM yyyy');
  static final _weekdayDayMonth = DateFormat('EEE, d MMM');
  static final _longDate = DateFormat('EEEE, d MMMM');
  static final _time = DateFormat('h:mm a');
  static final _weekdayShort = DateFormat('E');
  static final _month = DateFormat('MMMM');
  static final _monthYear = DateFormat('MMMM yyyy');

  String dayMonth(DateTime d) => _dayMonth.format(d);
  String fullDate(DateTime d) => _dayMonthYear.format(d);
  String longDate(DateTime d) => _longDate.format(d);
  String time(DateTime d) => _time.format(d);
  String weekdayInitial(DateTime d) => _weekdayShort.format(d).substring(0, 1);
  String weekdayShort(DateTime d) => _weekdayShort.format(d);
  String monthName(DateTime d) => _month.format(d);
  String monthYear(DateTime d) => _monthYear.format(d);

  /// "Today", "Yesterday", or "Mon, 19 Oct" (with year if not [now]'s year).
  String relativeDay(DateTime d, {required DateTime now}) {
    final day = DateTime(d.year, d.month, d.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (d.year != now.year) return _dayMonthYear.format(d);
    return _weekdayDayMonth.format(d);
  }

  /// Time-of-day greeting.
  static String greeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
