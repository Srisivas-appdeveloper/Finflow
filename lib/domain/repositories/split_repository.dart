import '../entities/split.dart';
import '../entities/transaction.dart';

class SplitNotFoundException implements Exception {
  const SplitNotFoundException(this.what, this.id);
  final String what;
  final String id;

  @override
  String toString() => '$what $id not found';
}

/// Thrown when removing a person who still appears in an expense or a
/// settlement, which would leave those amounts without an owner.
class MemberInUseException implements Exception {
  const MemberInUseException(this.name);
  final String name;

  @override
  String toString() => '$name is part of recorded expenses';
}

/// Groups that share costs, their expenses and settle-up payments.
///
/// The user's part of each expense is mirrored as a transaction, so it
/// counts in spending and insights:
/// * paid by the user: the full amount, with [Transaction.share] set to the
///   user's part (only that part counts as spending);
/// * paid by someone else: the user's part, paid by
///   [PaymentMethod.paidByOther];
/// * settlements the user pays or receives: a split settlement, which is a
///   movement (neither income nor spending).
abstract interface class SplitRepository {
  /// Emits whenever any stored financial data changes.
  Stream<void> get changes;

  /// Groups, oldest first.
  Future<List<SplitGroup>> groups();
  Future<SplitGroup> group(String id);

  /// Inserts when [group] has an empty id, otherwise replaces. New members
  /// with an empty id are given one. Throws [MemberInUseException] when a
  /// removed member still appears in the group's records.
  Future<SplitGroup> saveGroup(SplitGroup group);

  /// Deletes the group with its expenses and settlements. Their
  /// transactions stay in the user's history.
  Future<void> deleteGroup(String id);

  /// Expenses, newest first.
  Future<List<SplitExpense>> expenses({String? groupId});
  Future<SplitExpense> expense(String id);

  /// Saves [expense] and keeps the user's transaction for it in step.
  ///
  /// [method] is how the user paid when they are the payer; when omitted,
  /// the existing transaction's method is kept. [transactionId] turns an
  /// existing spend into this expense instead of creating a new one.
  Future<SplitExpense> saveExpense(
    SplitExpense expense, {
    PaymentMethod? method,
    String? transactionId,
  });

  /// Deletes the expense and the user's transaction for it.
  Future<void> deleteExpense(String id);

  /// Settlements, newest first.
  Future<List<SplitSettlement>> settlements({String? groupId});

  /// Saves [settlement]; when the user paid or received it, records the
  /// matching transaction.
  Future<SplitSettlement> saveSettlement(
    SplitSettlement settlement, {
    PaymentMethod method = PaymentMethod.upi,
  });

  Future<void> deleteSettlement(String id);

  /// The transaction mirroring a split expense or settlement, if any.
  Future<Transaction?> transactionFor(String splitId);
}
