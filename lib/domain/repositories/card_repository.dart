import '../entities/card_bill.dart';
import '../entities/credit_card.dart';
import '../entities/emi_plan.dart';
import '../entities/money.dart';
import '../entities/transaction.dart';

class CardDataNotFoundException implements Exception {
  const CardDataNotFoundException(this.what, this.id);
  final String what;
  final String id;

  @override
  String toString() => '$what $id not found';
}

/// Thrown when a bill for the same card and statement date already exists,
/// which prevents the same statement being entered twice.
class DuplicateBillException implements Exception {
  const DuplicateBillException();

  @override
  String toString() => 'A bill for this card and statement date exists';
}

/// Credit cards, their bills and instalment plans, entered manually.
abstract interface class CardRepository {
  /// Emits whenever any stored financial data changes.
  Stream<void> get changes;

  Future<List<CreditCard>> cards();
  Future<CreditCard> card(String id);

  /// Inserts when [card] has an empty id, otherwise replaces.
  Future<CreditCard> saveCard(CreditCard card);

  /// Deletes the card with its bills and EMI plans. Recorded payment
  /// transactions are kept in the history.
  Future<void> deleteCard(String id);

  /// Bills with [CardBill.paid] derived from linked payments, latest
  /// statement first.
  Future<List<CardBill>> bills({String? cardId});
  Future<CardBill> saveBill(CardBill bill);
  Future<void> deleteBill(String id);

  /// Records a payment towards a bill as a card-payment transaction (a
  /// movement, not spending) linked to the bill.
  Future<Transaction> recordPayment({
    required String billId,
    required Money amount,
    required DateTime paidOn,
    required PaymentMethod method,
  });

  Future<List<EmiPlan>> emis({String? cardId});
  Future<EmiPlan> saveEmi(EmiPlan plan);
  Future<void> deleteEmi(String id);
}
