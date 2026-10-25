/// Spending and income categories.
///
/// The declaration order of expense categories is significant: it fixes each
/// category's chart colour slot, so a category keeps the same colour
/// everywhere regardless of how it ranks.
enum TransactionCategory {
  groceries('Groceries', isIncome: false),
  dining('Food & dining', isIncome: false),
  transport('Transport', isIncome: false),
  shopping('Shopping', isIncome: false),
  bills('Bills & utilities', isIncome: false),
  entertainment('Entertainment', isIncome: false),
  health('Health', isIncome: false),
  travel('Travel', isIncome: false),
  salary('Salary', isIncome: true),
  refund('Refund', isIncome: true),
  transfer('Transfer', isIncome: null, isMovement: true),
  cardPayment('Card bill payment', isIncome: false, isMovement: true),
  fees('Fees & interest', isIncome: false),
  other('Other', isIncome: null),
  settlement('Split settlement', isIncome: null, isMovement: true);

  const TransactionCategory(
    this.label, {
    required this.isIncome,
    this.isMovement = false,
  });

  final String label;

  /// `true` for income-only, `false` for spending-only, `null` for either.
  final bool? isIncome;

  /// Money moved between the user's own accounts or used to settle a debt
  /// (e.g. paying a credit card bill). Real money movement, but neither
  /// income nor spending: the purchases on the card were already counted
  /// when they were made, so counting the bill payment would double them.
  final bool isMovement;

  /// Created by the app (from a card bill or a split), never picked by
  /// hand: the category is what links the payment to what it settles.
  bool get isSystem => this == cardPayment || this == settlement;

  static List<TransactionCategory> get spending =>
      values.where((c) => c.isIncome != true).toList();

  static List<TransactionCategory> get income =>
      values.where((c) => c.isIncome != false).toList();
}
