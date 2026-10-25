import '../../domain/entities/card_bill.dart';
import '../../domain/entities/credit_card.dart';
import '../../domain/entities/emi_plan.dart';
import '../../domain/entities/money.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_category.dart';
import '../../domain/repositories/card_repository.dart';
import '../sources/finance_store.dart';

class CardRepositoryImpl implements CardRepository {
  CardRepositoryImpl(this._store, this._changes);

  final FinanceStore _store;
  final DataChanges _changes;

  @override
  Stream<void> get changes => _changes.stream;

  // --- Cards ----------------------------------------------------------------

  @override
  Future<List<CreditCard>> cards() async =>
      (await _store.cards())..sort((a, b) => a.name.compareTo(b.name));

  @override
  Future<CreditCard> card(String id) async {
    for (final c in await _store.cards()) {
      if (c.id == id) return c;
    }
    throw CardDataNotFoundException('Card', id);
  }

  @override
  Future<CreditCard> saveCard(CreditCard card) async {
    if (card.name.trim().isEmpty) {
      throw ArgumentError.value(card.name, 'name', 'must not be empty');
    }
    if (!card.creditLimit.isPositive) {
      throw ArgumentError.value(card.creditLimit.minor, 'creditLimit');
    }
    for (final d in [card.statementDay, card.dueDay]) {
      if (d < 1 || d > 31) throw ArgumentError.value(d, 'day', 'must be 1-31');
    }
    final last4 = card.last4?.trim();
    if (last4 != null &&
        last4.isNotEmpty &&
        !RegExp(r'^\d{4}$').hasMatch(last4)) {
      throw ArgumentError.value(last4, 'last4', 'must be 4 digits');
    }
    final stored = CreditCard(
      id: card.id.isEmpty ? Ids.next('card') : card.id,
      name: card.name.trim(),
      issuer: card.issuer.trim(),
      last4: last4 == null || last4.isEmpty ? null : last4,
      creditLimit: card.creditLimit,
      statementDay: card.statementDay,
      dueDay: card.dueDay,
      currentOutstanding: card.currentOutstanding,
      outstandingUpdatedAt: card.outstandingUpdatedAt,
      styleIndex: card.styleIndex,
    );
    await _store.putCard(stored);
    _changes.notify();
    return stored;
  }

  @override
  Future<void> deleteCard(String id) async {
    await card(id);
    // Delete dependants explicitly so every store behaves the same.
    for (final b in await _store.bills()) {
      if (b.cardId == id) await _store.deleteBill(b.id);
    }
    for (final e in await _store.emis()) {
      if (e.cardId == id) await _store.deleteEmi(e.id);
    }
    await _store.deleteCard(id);
    _changes.notify();
  }

  // --- Bills ----------------------------------------------------------------

  @override
  Future<List<CardBill>> bills({String? cardId}) async {
    final payments = <String, int>{};
    for (final t in await _store.transactions()) {
      final billId = t.billId;
      if (billId == null || !t.affectsBalance) continue;
      // A refund of a payment (credit) reduces what was paid.
      payments[billId] =
          (payments[billId] ?? 0) +
          (t.isDebit ? t.amount.minor : -t.amount.minor);
    }
    final all = [
      for (final b in await _store.bills())
        if (cardId == null || b.cardId == cardId)
          b.copyWith(
            paid: Money(
              (payments[b.id] ?? 0).clamp(0, 1 << 52),
              currencyCode: b.totalDue.currencyCode,
            ),
          ),
    ]..sort((a, b) => b.statementDate.compareTo(a.statementDate));
    return all;
  }

  Future<CardBill> _bill(String id) async {
    for (final b in await bills()) {
      if (b.id == id) return b;
    }
    throw CardDataNotFoundException('Bill', id);
  }

  @override
  Future<CardBill> saveBill(CardBill bill) async {
    await card(bill.cardId);
    if (bill.totalDue.isNegative || bill.minimumDue.isNegative) {
      throw ArgumentError('Amounts must not be negative');
    }
    if (bill.minimumDue.minor > bill.totalDue.minor) {
      throw ArgumentError('Minimum due cannot exceed the total due');
    }
    if (bill.dueDate.isBefore(bill.statementDate)) {
      throw ArgumentError('The due date must be after the statement date');
    }
    final day = DateTime(
      bill.statementDate.year,
      bill.statementDate.month,
      bill.statementDate.day,
    );
    for (final existing in await _store.bills()) {
      final sameStatement =
          existing.cardId == bill.cardId &&
          existing.statementDate.year == day.year &&
          existing.statementDate.month == day.month &&
          existing.statementDate.day == day.day;
      if (sameStatement && existing.id != bill.id) {
        throw const DuplicateBillException();
      }
    }
    final stored = CardBill(
      id: bill.id.isEmpty ? Ids.next('bill') : bill.id,
      cardId: bill.cardId,
      statementDate: day,
      dueDate: DateTime(
        bill.dueDate.year,
        bill.dueDate.month,
        bill.dueDate.day,
      ),
      totalDue: bill.totalDue,
      minimumDue: bill.minimumDue,
    );
    await _store.putBill(stored);
    _changes.notify();
    return _bill(stored.id);
  }

  @override
  Future<void> deleteBill(String id) async {
    await _bill(id);
    await _store.deleteBill(id);
    _changes.notify();
  }

  @override
  Future<Transaction> recordPayment({
    required String billId,
    required Money amount,
    required DateTime paidOn,
    required PaymentMethod method,
  }) async {
    if (!amount.isPositive) {
      throw ArgumentError.value(amount.minor, 'amount', 'must be positive');
    }
    final bill = await _bill(billId);
    final c = await card(bill.cardId);
    final payment = Transaction(
      id: Ids.next('txn'),
      title: '${c.name} bill',
      amount: amount,
      direction: TransactionDirection.debit,
      category: TransactionCategory.cardPayment,
      status: TransactionStatus.completed,
      occurredAt: paidOn,
      paymentMethod: method,
      note: c.last4 == null ? null : 'Card •••• ${c.last4}',
      billId: bill.id,
    );
    await _store.putTransaction(payment);
    _changes.notify();
    return payment;
  }

  // --- EMIs -----------------------------------------------------------------

  @override
  Future<List<EmiPlan>> emis({String? cardId}) async => [
    for (final e in await _store.emis())
      if (cardId == null || e.cardId == cardId) e,
  ]..sort((a, b) => a.firstDueDate.compareTo(b.firstDueDate));

  @override
  Future<EmiPlan> saveEmi(EmiPlan plan) async {
    if (plan.cardId != null) await card(plan.cardId!);
    if (plan.title.trim().isEmpty) {
      throw ArgumentError.value(plan.title, 'title', 'must not be empty');
    }
    if (plan.tenureMonths < 1 || plan.tenureMonths > 120) {
      throw ArgumentError.value(plan.tenureMonths, 'tenureMonths', '1-120');
    }
    if (!plan.instalment.isPositive || !plan.principal.isPositive) {
      throw ArgumentError('Amounts must be positive');
    }
    final stored = EmiPlan(
      id: plan.id.isEmpty ? Ids.next('emi') : plan.id,
      title: plan.title.trim(),
      cardId: plan.cardId,
      principal: plan.principal,
      instalment: plan.instalment,
      tenureMonths: plan.tenureMonths,
      firstDueDate: plan.firstDueDate,
      annualInterestRate: plan.annualInterestRate,
      processingFee: plan.processingFee,
      closedOn: plan.closedOn,
    );
    await _store.putEmi(stored);
    _changes.notify();
    return stored;
  }

  @override
  Future<void> deleteEmi(String id) async {
    await _store.deleteEmi(id);
    _changes.notify();
  }
}
