import 'package:finflow/data/repositories/card_repository_impl.dart';
import 'package:finflow/data/repositories/data_management_repository_impl.dart';
import 'package:finflow/data/repositories/settings_repository_impl.dart';
import 'package:finflow/data/repositories/transaction_repository_impl.dart';
import 'package:finflow/data/sources/finance_store.dart';
import 'package:finflow/data/sources/key_value_store.dart';
import 'package:finflow/domain/entities/card_bill.dart';
import 'package:finflow/domain/entities/credit_card.dart';
import 'package:finflow/domain/entities/emi_plan.dart';
import 'package:finflow/domain/entities/money.dart';
import 'package:finflow/domain/entities/transaction.dart';
import 'package:finflow/domain/entities/transaction_category.dart';
import 'package:finflow/domain/repositories/card_repository.dart';
import 'package:finflow/domain/repositories/settings_repository.dart';
import 'package:finflow/domain/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/sample_data.dart';

Transaction draft({
  String title = 'Corner store',
  int minor = 25000,
  TransactionCategory category = TransactionCategory.groceries,
}) => Transaction(
  id: '',
  title: title,
  amount: Money(minor),
  direction: TransactionDirection.debit,
  category: category,
  status: TransactionStatus.completed,
  occurredAt: DateTime(2026, 10, 20, 10),
  paymentMethod: PaymentMethod.upi,
);

CreditCard cardDraft({String name = 'Travel card'}) => CreditCard(
  id: '',
  name: name,
  issuer: 'Bank',
  last4: '1234',
  creditLimit: const Money(10000000),
  statementDay: 12,
  dueDay: 2,
);

void main() {
  final now = DateTime(2026, 10, 24, 18, 30);

  group('Test fixture', () {
    test('fixture records are dated in the past with unique ids', () {
      final b = const SampleDataGenerator().generate(now);
      expect(b.transactions, isNotEmpty);
      expect(b.transactions.every((t) => !t.occurredAt.isAfter(now)), isTrue);
      expect(
        b.transactions.map((t) => t.id).toSet(),
        hasLength(b.transactions.length),
      );
    });

    test('is deterministic for the same date and seed', () {
      final a = const SampleDataGenerator().generate(now).transactions;
      final b = const SampleDataGenerator().generate(now).transactions;
      expect(
        a.map((t) => '${t.id}${t.title}${t.amount.minor}'),
        b.map((t) => '${t.id}${t.title}${t.amount.minor}'),
      );
    });
  });

  group('TransactionRepositoryImpl', () {
    late InMemoryFinanceStore store;
    late TransactionRepository repo;
    setUp(() {
      store = InMemoryFinanceStore();
      repo = TransactionRepositoryImpl(store, DataChanges());
    });

    test('add assigns an id, trims text and notifies', () async {
      final notified = expectLater(repo.changes, emits(null));
      final saved = await repo.add(
        draft(title: '  Corner store  ').copyWith(note: '  '),
      );
      expect(saved.id, startsWith('txn-'));
      expect(saved.title, 'Corner store');
      expect(saved.note, isNull);
      expect(await repo.getAll(), hasLength(1));
      await notified;
    });

    test('rejects empty titles and non-positive amounts', () async {
      expect(repo.add(draft(title: ' ')), throwsArgumentError);
      expect(repo.add(draft(minor: 0)), throwsArgumentError);
      expect(await repo.getAll(), isEmpty);
    });

    test('update and delete', () async {
      final saved = await repo.add(draft());
      await repo.update(
        saved.copyWith(title: 'Market', amount: const Money(1)),
      );
      expect((await repo.getById(saved.id)).title, 'Market');
      await repo.delete(saved.id);
      expect(
        repo.getById(saved.id),
        throwsA(isA<TransactionNotFoundException>()),
      );
    });
  });

  group('CardRepositoryImpl', () {
    late InMemoryFinanceStore store;
    late CardRepository repo;
    setUp(() {
      store = InMemoryFinanceStore();
      repo = CardRepositoryImpl(store, DataChanges());
    });

    Future<CardBill> addBill(String cardId, {int total = 500000}) =>
        repo.saveBill(
          CardBill(
            id: '',
            cardId: cardId,
            statementDate: DateTime(2026, 10, 12),
            dueDate: DateTime(2026, 11, 2),
            totalDue: Money(total),
            minimumDue: const Money(25000),
          ),
        );

    test('validates cards', () async {
      expect(repo.saveCard(cardDraft(name: '')), throwsArgumentError);
      expect(
        repo.saveCard(cardDraft().copyWith(last4: '12a4')),
        throwsArgumentError,
      );
    });

    test('bill paid amount is derived from linked payments', () async {
      final card = await repo.saveCard(cardDraft());
      final bill = await addBill(card.id);
      expect(bill.status, BillStatus.unpaid);

      await repo.recordPayment(
        billId: bill.id,
        amount: const Money(30000),
        paidOn: now,
        method: PaymentMethod.upi,
      );
      var updated = (await repo.bills()).single;
      expect(updated.paid.minor, 30000);
      expect(updated.status, BillStatus.minimumPaid);

      await repo.recordPayment(
        billId: bill.id,
        amount: const Money(470000),
        paidOn: now,
        method: PaymentMethod.bankTransfer,
      );
      updated = (await repo.bills()).single;
      expect(updated.status, BillStatus.paid);
      expect(updated.remaining.isZero, isTrue);

      // Payments are movements, not spending.
      final payments = await store.transactions();
      expect(payments, hasLength(2));
      expect(
        payments.every(
          (t) =>
              t.category == TransactionCategory.cardPayment &&
              t.category.isMovement &&
              t.billId == bill.id,
        ),
        isTrue,
      );
    });

    test('deleting a payment reopens the bill', () async {
      final card = await repo.saveCard(cardDraft());
      final bill = await addBill(card.id);
      final payment = await repo.recordPayment(
        billId: bill.id,
        amount: const Money(500000),
        paidOn: now,
        method: PaymentMethod.upi,
      );
      expect((await repo.bills()).single.isSettled, isTrue);
      await store.deleteTransaction(payment.id);
      expect((await repo.bills()).single.status, BillStatus.unpaid);
    });

    test('the same statement cannot be entered twice', () async {
      final card = await repo.saveCard(cardDraft());
      await addBill(card.id);
      expect(addBill(card.id), throwsA(isA<DuplicateBillException>()));
    });

    test('bill rules: minimum within total, due after statement', () async {
      final card = await repo.saveCard(cardDraft());
      expect(
        repo.saveBill(
          CardBill(
            id: '',
            cardId: card.id,
            statementDate: DateTime(2026, 10, 12),
            dueDate: DateTime(2026, 11, 2),
            totalDue: const Money(100),
            minimumDue: const Money(200),
          ),
        ),
        throwsArgumentError,
      );
      expect(
        repo.saveBill(
          CardBill(
            id: '',
            cardId: card.id,
            statementDate: DateTime(2026, 10, 12),
            dueDate: DateTime(2026, 10, 1),
            totalDue: const Money(100),
            minimumDue: const Money(10),
          ),
        ),
        throwsArgumentError,
      );
    });

    test(
      'deleting a card removes its bills and EMIs, keeps payments',
      () async {
        final card = await repo.saveCard(cardDraft());
        final bill = await addBill(card.id);
        await repo.recordPayment(
          billId: bill.id,
          amount: const Money(100),
          paidOn: now,
          method: PaymentMethod.upi,
        );
        await repo.saveEmi(
          EmiPlan(
            id: '',
            title: 'Phone',
            cardId: card.id,
            principal: const Money(600000),
            instalment: const Money(100000),
            tenureMonths: 6,
            firstDueDate: DateTime(2026, 11, 2),
          ),
        );
        await repo.deleteCard(card.id);
        expect(await repo.cards(), isEmpty);
        expect(await repo.bills(), isEmpty);
        expect(await repo.emis(), isEmpty);
        expect(await store.transactions(), hasLength(1));
      },
    );
  });

  group('DataManagementRepositoryImpl', () {
    test('clearAll removes everything', () async {
      final b = const SampleDataGenerator().generate(now);
      final store = InMemoryFinanceStore(
        transactions: b.transactions,
        cards: b.cards,
        bills: b.bills,
        emis: b.emis,
      );
      final repo = DataManagementRepositoryImpl(store, DataChanges());
      await repo.clearAll();
      expect(await store.transactions(), isEmpty);
      expect(await store.cards(), isEmpty);
    });

    test('CSV export escapes quotes and neutralises formulas', () async {
      final store = InMemoryFinanceStore(
        transactions: [
          draft(title: '=HYPERLINK("x")').copyWith(id: '1'),
          draft(title: 'Café, "Downtown"').copyWith(id: '2'),
        ],
      );
      final csv = await DataManagementRepositoryImpl(
        store,
        DataChanges(),
      ).exportTransactionsCsv();
      final lines = csv.trim().split('\n');
      expect(lines.first, startsWith('date,time,title,type,amount'));
      expect(csv, contains('"\'=HYPERLINK(""x"")"'));
      expect(csv, contains('"Café, ""Downtown"""'));
      expect(csv, contains('250.00'));
      expect(DataManagementRepositoryImpl.csvCell('-120'), '-120');
      expect(DataManagementRepositoryImpl.csvCell('-cmd'), "'-cmd");
    });
  });

  group('SettingsRepositoryImpl', () {
    test('defaults and persistence', () async {
      final store = InMemoryStore();
      final repo = SettingsRepositoryImpl(store);
      expect(repo.themePreference, AppThemePreference.system);
      expect(repo.onboardingComplete, isFalse);
      expect(repo.remindersEnabled, isFalse);
      await repo.setThemePreference(AppThemePreference.dark);
      await repo.setOnboardingComplete(true);
      await repo.setRemindersEnabled(true);
      final reread = SettingsRepositoryImpl(store);
      expect(reread.themePreference, AppThemePreference.dark);
      expect(reread.onboardingComplete, isTrue);
      expect(reread.remindersEnabled, isTrue);
    });

    test('ignores unknown stored values', () {
      final repo = SettingsRepositoryImpl(
        InMemoryStore({SettingsRepositoryImpl.themeKey: 'purple'}),
      );
      expect(repo.themePreference, AppThemePreference.system);
    });
  });
}
