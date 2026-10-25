/// Route names. Use the helpers to build paths with parameters.
///
/// No route is registered at `/`: GetX matches every path prefix, so a `/`
/// route would swallow unknown paths instead of showing the not-found page.
abstract final class AppRoutes {
  static const shell = '/home';
  static const onboarding = '/welcome';
  static const transactionDetails = '/transactions/:id';
  static const privacy = '/privacy';
  static const addTransaction = '/add-transaction';
  static const editTransaction = '/edit-transaction/:id';
  static const cardDetails = '/cards/:id';
  static const split = '/split';
  static const splitGroup = '/split/:id';
  static const splitExpense = '/split-expense/:group';

  static String editTransactionOf(String id) =>
      '/edit-transaction/${Uri.encodeComponent(id)}';

  static String card(String id) => '/cards/${Uri.encodeComponent(id)}';

  static String splitGroupOf(String id) => '/split/${Uri.encodeComponent(id)}';

  /// The expense form for a group: a new expense, [expenseId] to edit one,
  /// or [transactionId] to split an existing spend.
  static String splitExpenseOf(
    String groupId, {
    String? expenseId,
    String? transactionId,
  }) {
    final path = '/split-expense/${Uri.encodeComponent(groupId)}';
    final query = {'expense': ?expenseId, 'transaction': ?transactionId};
    if (query.isEmpty) return path;
    return '$path?${Uri(queryParameters: query).query}';
  }

  static String transaction(String id) =>
      '/transactions/${Uri.encodeComponent(id)}';
}
