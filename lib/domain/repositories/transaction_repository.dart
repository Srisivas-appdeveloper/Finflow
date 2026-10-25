import '../entities/transaction.dart';
import '../entities/transaction_category.dart';

class TransactionNotFoundException implements Exception {
  const TransactionNotFoundException(this.id);
  final String id;

  @override
  String toString() => 'Transaction $id not found';
}

/// The contract the UI and business logic depend on.
///
/// Implementations live in the data layer; the storage behind it can change
/// (on-device database today, synchronised sources later) without changes
/// above this interface.
abstract interface class TransactionRepository {
  /// Emits whenever any stored financial data changes, so screens refresh.
  Stream<void> get changes;

  /// All transactions, newest first.
  Future<List<Transaction>> getAll();

  /// Throws [TransactionNotFoundException] if [id] is unknown.
  Future<Transaction> getById(String id);

  /// Stores a new transaction. The id of [draft] is ignored and a new one
  /// assigned.
  Future<Transaction> add(Transaction draft);

  /// Replaces an existing transaction.
  Future<Transaction> update(Transaction transaction);

  Future<void> delete(String id);

  Future<Transaction> updateCategory(String id, TransactionCategory category);
}
