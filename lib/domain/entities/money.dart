import 'package:meta/meta.dart';

/// An amount of money in integer minor units (e.g. paise, cents).
///
/// Integer storage avoids floating-point rounding errors in sums.
@immutable
class Money implements Comparable<Money> {
  const Money(this.minor, {this.currencyCode = 'INR'});

  const Money.zero({this.currencyCode = 'INR'}) : minor = 0;

  /// Builds from a major-unit amount such as `12.50`.
  factory Money.fromMajor(num amount, {String currencyCode = 'INR'}) =>
      Money((amount * 100).round(), currencyCode: currencyCode);

  /// Amount in minor units. Negative values represent outflows.
  final int minor;

  /// ISO 4217 currency code.
  final String currencyCode;

  double get major => minor / 100;
  bool get isZero => minor == 0;
  bool get isNegative => minor < 0;
  bool get isPositive => minor > 0;

  Money abs() => Money(minor.abs(), currencyCode: currencyCode);

  Money operator -() => Money(-minor, currencyCode: currencyCode);

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(minor + other.minor, currencyCode: currencyCode);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(minor - other.minor, currencyCode: currencyCode);
  }

  /// Integer division, rounding to the nearest minor unit.
  Money divide(int divisor) =>
      Money((minor / divisor).round(), currencyCode: currencyCode);

  void _assertSameCurrency(Money other) {
    if (other.currencyCode != currencyCode) {
      throw ArgumentError(
        'Cannot combine $currencyCode with ${other.currencyCode}',
      );
    }
  }

  @override
  int compareTo(Money other) => minor.compareTo(other.minor);

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minor == minor &&
      other.currencyCode == currencyCode;

  @override
  int get hashCode => Object.hash(minor, currencyCode);

  @override
  String toString() => 'Money($minor $currencyCode)';
}
