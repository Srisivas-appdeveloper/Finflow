import '../../domain/entities/money.dart';

/// Parses user-typed amounts such as "1,250.5" into [Money].
///
/// Returns null for empty or invalid input. Digits are parsed exactly (no
/// floating point), so "0.1" is exactly 10 minor units.
Money? parseMoney(String text, {String currencyCode = 'INR'}) {
  final cleaned = text.replaceAll(RegExp(r'[,\s₹]'), '');
  final match = RegExp(r'^(\d{1,12})(?:\.(\d{0,2}))?$').firstMatch(cleaned);
  if (match == null) return null;
  final whole = int.parse(match.group(1)!);
  final fraction = (match.group(2) ?? '').padRight(2, '0');
  return Money(whole * 100 + int.parse(fraction), currencyCode: currencyCode);
}

/// Formats [money] for editing in a text field ("1250.50", no grouping).
String moneyInputText(Money money) => money.abs().major.toStringAsFixed(2);
