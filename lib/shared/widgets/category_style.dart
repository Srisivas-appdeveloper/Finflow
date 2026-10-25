import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/transaction_category.dart';

/// Visual identity (icon + colour) for each category.
///
/// Spending categories take the categorical chart slots in declaration order,
/// so a category's colour is fixed by what it is, never by how it ranks.
abstract final class CategoryStyle {
  static IconData icon(TransactionCategory? category) => switch (category) {
    TransactionCategory.groceries => Icons.local_grocery_store_rounded,
    TransactionCategory.dining => Icons.restaurant_rounded,
    TransactionCategory.transport => Icons.directions_car_filled_rounded,
    TransactionCategory.shopping => Icons.shopping_bag_rounded,
    TransactionCategory.bills => Icons.receipt_long_rounded,
    TransactionCategory.entertainment => Icons.movie_rounded,
    TransactionCategory.health => Icons.favorite_rounded,
    TransactionCategory.travel => Icons.flight_rounded,
    TransactionCategory.salary => Icons.payments_rounded,
    TransactionCategory.refund => Icons.replay_rounded,
    TransactionCategory.transfer => Icons.swap_horiz_rounded,
    TransactionCategory.cardPayment => Icons.credit_score_rounded,
    TransactionCategory.fees => Icons.percent_rounded,
    TransactionCategory.other || null => Icons.more_horiz_rounded,
    TransactionCategory.settlement => Icons.handshake_rounded,
  };

  /// Spending categories take the categorical slots in declaration order,
  /// so a category's colour is fixed by what it is, never by how it ranks.
  static Color color(BuildContext context, TransactionCategory? category) {
    final fin = context.fin;
    return switch (category) {
      TransactionCategory.salary || TransactionCategory.refund => fin.income,
      TransactionCategory.transfer ||
      TransactionCategory.cardPayment ||
      TransactionCategory.settlement => fin.accent,
      TransactionCategory.fees => fin.failed,
      TransactionCategory.other || null => fin.neutralCategory,
      final c => fin.categorical[c.index % fin.categorical.length],
    };
  }

  static String label(TransactionCategory? category) =>
      category?.label ?? 'Everything else';
}

/// Round icon badge representing a category.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({super.key, required this.category, this.size = 44});

  final TransactionCategory? category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = CategoryStyle.color(context, category);
    final dark = Theme.of(context).brightness == Brightness.dark;
    // A small glass bubble tinted with the category colour.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: dark ? 0.38 : 0.26),
            color.withValues(alpha: dark ? 0.12 : 0.08),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? 0.22 : 0.8),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        CategoryStyle.icon(category),
        size: size * 0.46,
        color: dark ? Color.lerp(color, Colors.white, 0.25) : color,
        semanticLabel: CategoryStyle.label(category),
      ),
    );
  }
}
