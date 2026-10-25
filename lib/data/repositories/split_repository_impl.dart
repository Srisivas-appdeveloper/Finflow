import '../../domain/entities/split.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_category.dart';
import '../../domain/repositories/split_repository.dart';
import '../sources/finance_store.dart';

class SplitRepositoryImpl implements SplitRepository {
  SplitRepositoryImpl(this._store, this._changes);

  final FinanceStore _store;
  final DataChanges _changes;

  @override
  Stream<void> get changes => _changes.stream;

  // --- Groups ---------------------------------------------------------------

  @override
  Future<List<SplitGroup>> groups() async =>
      (await _store.splitGroups())
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  @override
  Future<SplitGroup> group(String id) async {
    for (final g in await _store.splitGroups()) {
      if (g.id == id) return g;
    }
    throw SplitNotFoundException('Group', id);
  }

  @override
  Future<SplitGroup> saveGroup(SplitGroup group) async {
    final name = group.name.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(group.name, 'name', 'must not be empty');
    }
    final members = [
      for (final m in group.members)
        SplitMember(
          id: m.id.isEmpty ? Ids.next('mem') : m.id,
          name: m.name.trim(),
        ),
    ];
    if (members.isEmpty) {
      throw ArgumentError('Add at least one other person');
    }
    final seen = <String>{};
    for (final m in members) {
      final key = m.name.toLowerCase();
      if (key.isEmpty) throw ArgumentError('Every person needs a name');
      if (key == 'you' || key == 'me') {
        throw ArgumentError('You are already in the group');
      }
      if (!seen.add(key)) throw ArgumentError('${m.name} is listed twice');
    }

    final existing = group.id.isEmpty ? null : await this.group(group.id);
    if (existing != null) {
      final kept = {for (final m in members) m.id};
      final removed = existing.members.where((m) => !kept.contains(m.id));
      if (removed.isNotEmpty) {
        final expenses = await this.expenses(groupId: group.id);
        final settlements = await this.settlements(groupId: group.id);
        for (final m in removed) {
          if (expenses.any((e) => e.involves(m.id)) ||
              settlements.any((s) => s.involves(m.id))) {
            throw MemberInUseException(m.name);
          }
        }
      }
    }

    final stored = SplitGroup(
      id: existing?.id ?? Ids.next('grp'),
      name: name,
      members: members,
      createdAt: existing?.createdAt ?? group.createdAt,
    );
    await _store.putSplitGroup(stored);
    _changes.notify();
    return stored;
  }

  @override
  Future<void> deleteGroup(String id) async {
    final g = await group(id);
    final records = {
      for (final e in await expenses(groupId: id)) e.id,
      for (final s in await settlements(groupId: id)) s.id,
    };
    // Keep the user's transactions (their share still counts as spending)
    // but detach them from records that no longer exist.
    await _store.putAll(
      transactions: [
        for (final t in await _store.transactions())
          if (records.contains(t.splitId)) t.copyWith(clearSplit: true),
      ],
    );
    for (final e in await _store.splitExpenses()) {
      if (e.groupId == g.id) await _store.deleteSplitExpense(e.id);
    }
    for (final s in await _store.splitSettlements()) {
      if (s.groupId == g.id) await _store.deleteSplitSettlement(s.id);
    }
    await _store.deleteSplitGroup(g.id);
    _changes.notify();
  }

  // --- Expenses -------------------------------------------------------------

  @override
  Future<List<SplitExpense>> expenses({String? groupId}) async => [
    for (final e in await _store.splitExpenses())
      if (groupId == null || e.groupId == groupId) e,
  ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

  @override
  Future<SplitExpense> expense(String id) async {
    for (final e in await _store.splitExpenses()) {
      if (e.id == id) return e;
    }
    throw SplitNotFoundException('Expense', id);
  }

  @override
  Future<Transaction?> transactionFor(String splitId) async {
    for (final t in await _store.transactions()) {
      if (t.splitId == splitId) return t;
    }
    return null;
  }

  Future<Transaction> _transaction(String id) async {
    for (final t in await _store.transactions()) {
      if (t.id == id) return t;
    }
    throw SplitNotFoundException('Transaction', id);
  }

  @override
  Future<SplitExpense> saveExpense(
    SplitExpense expense, {
    PaymentMethod? method,
    String? transactionId,
  }) async {
    final g = await group(expense.groupId);
    final title = expense.title.trim();
    if (title.isEmpty) {
      throw ArgumentError.value(expense.title, 'title', 'must not be empty');
    }
    if (!expense.amount.isPositive) {
      throw ArgumentError('The amount must be more than zero');
    }
    if (expense.category.isSystem || expense.category.isIncome == true) {
      throw ArgumentError.value(expense.category, 'category');
    }
    if (!g.has(expense.paidBy)) {
      throw ArgumentError('Choose who paid');
    }
    final shares = [
      for (final s in expense.shares)
        if (s.amount.isPositive) s,
    ];
    if (shares.isEmpty) throw ArgumentError('Choose who shares this');
    var total = 0;
    final ids = <String>{};
    for (final s in shares) {
      if (!g.has(s.memberId) || !ids.add(s.memberId)) {
        throw ArgumentError.value(s.memberId, 'shares');
      }
      total += s.amount.minor;
    }
    if (total != expense.amount.minor) {
      throw ArgumentError('The shares must add up to the amount');
    }

    final id = expense.id.isEmpty ? Ids.next('spx') : expense.id;
    if (expense.id.isNotEmpty) await this.expense(id);
    final stored = SplitExpense(
      id: id,
      groupId: g.id,
      title: title,
      amount: expense.amount,
      category: expense.category,
      paidBy: expense.paidBy,
      mode: expense.mode,
      shares: shares,
      occurredAt: expense.occurredAt,
    );

    // The user's transaction for this expense: the one already linked, or
    // the spend being split.
    var linked = await transactionFor(id);
    if (linked == null && transactionId != null) {
      final t = await _transaction(transactionId);
      if (t.isCredit || t.billId != null || t.isSplit) {
        throw ArgumentError('This transaction can\'t be split');
      }
      linked = t;
    }
    final mirror = _mirror(stored, linked, method);
    await _store.putAll(splitExpenses: [stored], transactions: [?mirror]);
    if (mirror == null && linked != null) {
      await _store.deleteTransaction(linked.id);
    }
    _changes.notify();
    return stored;
  }

  /// The transaction recording what [e] means for the user, or null when
  /// the user neither paid nor shares it.
  static Transaction? _mirror(
    SplitExpense e,
    Transaction? existing,
    PaymentMethod? method,
  ) {
    final yours = e.yourShare;
    if (!e.paidByYou && !yours.isPositive) return null;
    final paidMethod = e.paidByYou
        ? method ??
              (existing == null ||
                      existing.paymentMethod == PaymentMethod.paidByOther
                  ? PaymentMethod.upi
                  : existing.paymentMethod)
        : PaymentMethod.paidByOther;
    return Transaction(
      id: existing?.id ?? Ids.next('txn'),
      title: e.title,
      // Paid by you: the whole amount left your account, your part counts.
      // Paid by someone else: you owe your part; that part counts.
      amount: e.paidByYou ? e.amount : yours,
      share: e.paidByYou ? yours : null,
      direction: TransactionDirection.debit,
      category: e.category,
      status: existing?.status ?? TransactionStatus.completed,
      occurredAt: e.occurredAt,
      paymentMethod: paidMethod,
      reference: existing?.reference,
      note: existing?.note,
      splitId: e.id,
    );
  }

  @override
  Future<void> deleteExpense(String id) async {
    await expense(id);
    final linked = await transactionFor(id);
    if (linked != null) await _store.deleteTransaction(linked.id);
    await _store.deleteSplitExpense(id);
    _changes.notify();
  }

  // --- Settlements ----------------------------------------------------------

  @override
  Future<List<SplitSettlement>> settlements({String? groupId}) async => [
    for (final s in await _store.splitSettlements())
      if (groupId == null || s.groupId == groupId) s,
  ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

  Future<SplitSettlement> _settlement(String id) async {
    for (final s in await _store.splitSettlements()) {
      if (s.id == id) return s;
    }
    throw SplitNotFoundException('Settlement', id);
  }

  @override
  Future<SplitSettlement> saveSettlement(
    SplitSettlement settlement, {
    PaymentMethod method = PaymentMethod.upi,
  }) async {
    final g = await group(settlement.groupId);
    if (!g.has(settlement.fromId) || !g.has(settlement.toId)) {
      throw ArgumentError('Choose who paid and who received');
    }
    if (settlement.fromId == settlement.toId) {
      throw ArgumentError('Choose two different people');
    }
    if (!settlement.amount.isPositive) {
      throw ArgumentError('The amount must be more than zero');
    }
    final id = settlement.id.isEmpty ? Ids.next('stl') : settlement.id;
    if (settlement.id.isNotEmpty) await _settlement(id);
    final stored = SplitSettlement(
      id: id,
      groupId: g.id,
      fromId: settlement.fromId,
      toId: settlement.toId,
      amount: settlement.amount,
      occurredAt: settlement.occurredAt,
    );

    final linked = await transactionFor(id);
    final youPaid = stored.fromId == SplitMember.youId;
    final youReceived = stored.toId == SplitMember.youId;
    final mirror = youPaid || youReceived
        ? Transaction(
            id: linked?.id ?? Ids.next('txn'),
            title: g.nameOf(youPaid ? stored.toId : stored.fromId),
            amount: stored.amount,
            direction: youPaid
                ? TransactionDirection.debit
                : TransactionDirection.credit,
            category: TransactionCategory.settlement,
            status: TransactionStatus.completed,
            occurredAt: stored.occurredAt,
            paymentMethod: method,
            note: 'Settle up · ${g.name}',
            splitId: id,
          )
        : null;
    await _store.putAll(splitSettlements: [stored], transactions: [?mirror]);
    if (mirror == null && linked != null) {
      await _store.deleteTransaction(linked.id);
    }
    _changes.notify();
    return stored;
  }

  @override
  Future<void> deleteSettlement(String id) async {
    await _settlement(id);
    final linked = await transactionFor(id);
    if (linked != null) await _store.deleteTransaction(linked.id);
    await _store.deleteSplitSettlement(id);
    _changes.notify();
  }
}
