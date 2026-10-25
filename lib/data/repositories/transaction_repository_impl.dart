import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_category.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../sources/finance_store.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl(this._store, this._changes);

  final FinanceStore _store;
  final DataChanges _changes;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<Transaction>> getAll() async {
    final all = await _store.transactions()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return all;
  }

  @override
  Future<Transaction> getById(String id) async {
    for (final t in await _store.transactions()) {
      if (t.id == id) return t;
    }
    throw TransactionNotFoundException(id);
  }

  @override
  Future<Transaction> add(Transaction draft) async {
    _validate(draft);
    final stored = Transaction(
      id: Ids.next('txn'),
      title: draft.title.trim(),
      amount: draft.amount,
      direction: draft.direction,
      category: draft.category,
      status: draft.status,
      occurredAt: draft.occurredAt,
      paymentMethod: draft.paymentMethod,
      reference: draft.reference,
      note: _clean(draft.note),
      billId: draft.billId,
      share: draft.share,
      splitId: draft.splitId,
    );
    await _store.putTransaction(stored);
    _changes.notify();
    return stored;
  }

  @override
  Future<Transaction> update(Transaction transaction) async {
    await getById(transaction.id);
    _validate(transaction);
    final stored = transaction.copyWith(
      title: transaction.title.trim(),
      note: _clean(transaction.note),
      clearNote: _clean(transaction.note) == null,
    );
    await _store.putTransaction(stored);
    _changes.notify();
    return stored;
  }

  @override
  Future<void> delete(String id) async {
    final t = await getById(id);
    await _store.deleteTransaction(id);
    // A split transaction is the user's side of a group record; removing
    // it removes that record too, so balances never count a deleted spend.
    final splitId = t.splitId;
    if (splitId != null) {
      await _store.deleteSplitExpense(splitId);
      await _store.deleteSplitSettlement(splitId);
    }
    _changes.notify();
  }

  @override
  Future<Transaction> updateCategory(
    String id,
    TransactionCategory category,
  ) async {
    final current = await getById(id);
    final stored = current.copyWith(category: category);
    await _store.putTransaction(stored);
    _changes.notify();
    return stored;
  }

  static String? _clean(String? note) {
    final n = note?.trim();
    return n == null || n.isEmpty ? null : n;
  }

  static void _validate(Transaction t) {
    if (t.title.trim().isEmpty) {
      throw ArgumentError.value(t.title, 'title', 'must not be empty');
    }
    if (!t.amount.isPositive) {
      throw ArgumentError.value(t.amount.minor, 'amount', 'must be positive');
    }
    final share = t.share;
    if (share != null && (share.isNegative || share.minor > t.amount.minor)) {
      throw ArgumentError.value(share.minor, 'share', 'must be 0 to amount');
    }
  }
}
