import 'package:finflow/core/utils/formatters.dart';
import 'package:finflow/domain/entities/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money', () {
    test('stores minor units and avoids float drift', () {
      final a = Money.fromMajor(0.1);
      final b = Money.fromMajor(0.2);
      expect((a + b).minor, 30);
      expect((a + b).major, 0.3);
    });

    test('arithmetic and sign helpers', () {
      const m = Money(1250);
      expect((-m).isNegative, isTrue);
      expect((-m).abs(), m);
      expect((m - const Money(250)).minor, 1000);
      expect(const Money(1000).divide(3).minor, 333);
    });

    test('refuses to mix currencies', () {
      expect(
        () => const Money(1) + const Money(1, currencyCode: 'USD'),
        throwsArgumentError,
      );
    });
  });

  group('Formatters.money', () {
    final f = Formatters(locale: 'en_IN');

    test('uses Indian digit grouping and currency symbol', () {
      expect(f.money(const Money(12345678)), '₹1,23,456.78');
    });

    test('signs', () {
      expect(f.money(const Money(-5000)), '−₹50.00');
      expect(f.money(const Money(5000), signed: true), '+₹50.00');
      expect(f.money(const Money(0), signed: true), '₹0.00');
    });

    test('relative day labels', () {
      final now = DateTime(2026, 10, 24, 12);
      expect(f.relativeDay(DateTime(2026, 10, 24, 1), now: now), 'Today');
      expect(f.relativeDay(DateTime(2026, 10, 23, 23), now: now), 'Yesterday');
      expect(f.relativeDay(DateTime(2026, 10, 19), now: now), 'Mon, 19 Oct');
      expect(f.relativeDay(DateTime(2025, 10, 19), now: now), '19 Oct 2025');
    });
  });
}
