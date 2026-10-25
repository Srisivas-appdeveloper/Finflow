// TEST FIXTURE ONLY. Fictional data used by automated tests; never part of
// the app. All payee and card names are invented.

import 'dart:math';

import 'package:finflow/domain/entities/card_bill.dart';
import 'package:finflow/domain/entities/credit_card.dart';
import 'package:finflow/domain/entities/emi_plan.dart';
import 'package:finflow/domain/entities/money.dart';
import 'package:finflow/domain/entities/transaction.dart';
import 'package:finflow/domain/entities/transaction_category.dart';

/// Everything [SampleDataGenerator] produces in one go.
class SampleBundle {
  const SampleBundle({
    required this.transactions,
    required this.cards,
    required this.bills,
    required this.emis,
  });

  final List<Transaction> transactions;
  final List<CreditCard> cards;
  final List<CardBill> bills;
  final List<EmiPlan> emis;
}

/// Deterministic generator of fictional data relative to "now".
class SampleDataGenerator {
  const SampleDataGenerator({this.seed = 20261024, this.currencyCode = 'INR'});

  final int seed;
  final String currencyCode;

  SampleBundle generate(DateTime now) {
    final transactions = generateTransactions(now);
    Money m(int minor) => Money(minor, currencyCode: currencyCode);
    DateTime day(int y, int mo, int d) => DateTime(y, mo, d);

    const cardA = 'sample-card-1';
    const cardB = 'sample-card-2';
    final cards = [
      CreditCard(
        id: cardA,
        name: 'Everyday card',
        issuer: 'Aurora Bank',
        last4: '4821',
        creditLimit: m(30000000),
        statementDay: 12,
        dueDay: 2,
        currentOutstanding: m(4615000),
        outstandingUpdatedAt: now.subtract(const Duration(days: 1)),
        styleIndex: 0,
      ),
      CreditCard(
        id: cardB,
        name: 'Travel card',
        issuer: 'Northwind Bank',
        last4: '0937',
        creditLimit: m(50000000),
        statementDay: 20,
        dueDay: 8,
        styleIndex: 2,
      ),
    ];

    // Latest statement of each card, plus a settled older one.
    final aStatement = _lastOccurrence(now, 12);
    final bStatement = _lastOccurrence(now, 20);
    final bills = [
      CardBill(
        id: 'sample-bill-1',
        cardId: cardA,
        statementDate: aStatement,
        dueDate: aStatement.add(const Duration(days: 20)),
        totalDue: m(3842050),
        minimumDue: m(192100),
      ),
      CardBill(
        id: 'sample-bill-2',
        cardId: cardB,
        statementDate: bStatement,
        dueDate: bStatement.add(const Duration(days: 18)),
        totalDue: m(1285000),
        minimumDue: m(64250),
      ),
      CardBill(
        id: 'sample-bill-3',
        cardId: cardA,
        statementDate: day(aStatement.year, aStatement.month - 1, 12),
        dueDate: day(
          aStatement.year,
          aStatement.month - 1,
          12,
        ).add(const Duration(days: 20)),
        totalDue: m(2910000),
        minimumDue: m(145500),
      ),
    ];

    // Payments: the old bill fully, the travel card partly.
    final payments = [
      Transaction(
        id: 'sample-pay-1',
        title: 'Everyday card bill',
        amount: m(2910000),
        direction: TransactionDirection.debit,
        category: TransactionCategory.cardPayment,
        status: TransactionStatus.completed,
        occurredAt: bills[2].dueDate.subtract(const Duration(days: 2)),
        paymentMethod: PaymentMethod.bankTransfer,
        reference: 'REF-PAYMENT01',
        billId: 'sample-bill-3',
      ),
      if (!bStatement.add(const Duration(days: 3)).isAfter(now))
        Transaction(
          id: 'sample-pay-2',
          title: 'Travel card bill',
          amount: m(300000),
          direction: TransactionDirection.debit,
          category: TransactionCategory.cardPayment,
          status: TransactionStatus.completed,
          occurredAt: bStatement.add(const Duration(days: 3)),
          paymentMethod: PaymentMethod.upi,
          reference: 'REF-PAYMENT02',
          billId: 'sample-bill-2',
        ),
    ];

    final emis = [
      EmiPlan(
        id: 'sample-emi-1',
        title: 'Laptop (Gadget Hub)',
        cardId: cardA,
        principal: m(8999000),
        instalment: m(799100),
        tenureMonths: 12,
        firstDueDate: day(now.year, now.month - 4, 2),
        annualInterestRate: 13,
        processingFee: m(19900),
      ),
      EmiPlan(
        id: 'sample-emi-2',
        title: 'Phone (no-cost EMI)',
        cardId: cardB,
        principal: m(4500000),
        instalment: m(750000),
        tenureMonths: 6,
        firstDueDate: day(now.year, now.month - 1, 8),
      ),
    ];

    return SampleBundle(
      transactions: [...transactions, ...payments],
      cards: cards,
      bills: bills,
      emis: emis,
    );
  }

  /// Most recent date on or before [now] that falls on [dayOfMonth].
  static DateTime _lastOccurrence(DateTime now, int dayOfMonth) {
    final thisMonth = DateTime(now.year, now.month, dayOfMonth);
    return thisMonth.isAfter(now)
        ? DateTime(now.year, now.month - 1, dayOfMonth)
        : thisMonth;
  }

  List<Transaction> generateTransactions(DateTime now) {
    final rng = Random(seed);
    final drafts = <_Draft>[];
    const days = 75;

    for (var offset = days; offset >= 0; offset--) {
      final day = DateTime(now.year, now.month, now.day - offset);

      if (day.day == 1) {
        drafts.add(
          _Draft(
            day,
            9,
            'Acme Studio Payroll',
            TransactionCategory.salary,
            8500000,
            PaymentMethod.bankTransfer,
            credit: true,
            note: 'Monthly salary',
          ),
        );
      }
      if (day.day == 3) {
        drafts.add(
          _Draft(
            day,
            10,
            'Maple Residency Rent',
            TransactionCategory.bills,
            2200000,
            PaymentMethod.bankTransfer,
            note: 'Apartment rent',
          ),
        );
      }
      if (day.day == 5) {
        drafts.add(
          _Draft(
            day,
            8,
            'StreamBox Premium',
            TransactionCategory.entertainment,
            64900,
            PaymentMethod.card,
          ),
        );
        drafts.add(
          _Draft(
            day,
            9,
            'AirWave Mobile',
            TransactionCategory.bills,
            59900,
            PaymentMethod.upi,
          ),
        );
      }
      if (day.day == 7) {
        drafts.add(
          _Draft(
            day,
            11,
            'City Power & Light',
            TransactionCategory.bills,
            180000 + rng.nextInt(90000),
            PaymentMethod.upi,
          ),
        );
      }
      if (day.day == 10) {
        drafts.add(
          _Draft(
            day,
            7,
            'FitLife Gym',
            TransactionCategory.health,
            150000,
            PaymentMethod.card,
          ),
        );
      }
      if (day.day == 15) {
        drafts.add(
          _Draft(
            day,
            18,
            'Transfer to savings',
            TransactionCategory.transfer,
            1000000,
            PaymentMethod.bankTransfer,
          ),
        );
      }

      // Everyday spending.
      final dailyCount = 1 + rng.nextInt(3);
      for (var i = 0; i < dailyCount; i++) {
        final pick = _everyday[rng.nextInt(_everyday.length)];
        final amount = pick.min + rng.nextInt(pick.max - pick.min + 1);
        drafts.add(
          _Draft(
            day,
            8 + rng.nextInt(14),
            pick.name,
            pick.category,
            amount,
            pick.methods[rng.nextInt(pick.methods.length)],
          ),
        );
      }

      // Occasional larger purchases.
      if (rng.nextDouble() < 0.12) {
        final pick = _occasional[rng.nextInt(_occasional.length)];
        drafts.add(
          _Draft(
            day,
            12 + rng.nextInt(8),
            pick.name,
            pick.category,
            pick.min + rng.nextInt(pick.max - pick.min + 1),
            PaymentMethod.card,
          ),
        );
      }
    }

    // A refund, a pending payment and a failed payment for state coverage.
    drafts.add(
      _Draft(
        DateTime(now.year, now.month, now.day - 4),
        16,
        'Urban Threads',
        TransactionCategory.refund,
        189900,
        PaymentMethod.card,
        credit: true,
        note: 'Returned jacket',
      ),
    );
    drafts.add(
      _Draft(
        DateTime(now.year, now.month, now.day - 1),
        20,
        'SkyHop Airlines',
        TransactionCategory.travel,
        742000,
        PaymentMethod.card,
        status: TransactionStatus.pending,
      ),
    );
    drafts.add(
      _Draft(
        DateTime(now.year, now.month, now.day - 2),
        13,
        'Gadget Hub',
        TransactionCategory.shopping,
        349900,
        PaymentMethod.upi,
        status: TransactionStatus.failed,
        note: 'Payment declined',
      ),
    );

    final transactions = <Transaction>[];
    for (final d in drafts) {
      var at = DateTime(
        d.day.year,
        d.day.month,
        d.day.day,
        d.hour,
        rng.nextInt(60),
      );
      // Later today: pull into the past so nothing is dated in the future.
      if (at.isAfter(now)) {
        at = now.subtract(Duration(minutes: 5 + rng.nextInt(30)));
        if (at.day != now.day) continue;
      }
      transactions.add(
        Transaction(
          id: '',
          title: d.title,
          amount: Money(d.minor, currencyCode: currencyCode),
          direction: d.credit
              ? TransactionDirection.credit
              : TransactionDirection.debit,
          category: d.category,
          status: d.status,
          occurredAt: at,
          paymentMethod: d.method,
          note: d.note,
        ),
      );
    }

    transactions.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return [
      for (var i = 0; i < transactions.length; i++)
        _withId(transactions[i], i, rng),
    ];
  }

  Transaction _withId(Transaction t, int index, Random rng) {
    final id = 'sample-${(index + 1).toString().padLeft(4, '0')}';
    final ref = List.generate(
      10,
      (_) => _refChars[rng.nextInt(_refChars.length)],
    ).join();
    return Transaction(
      id: id,
      title: t.title,
      amount: t.amount,
      direction: t.direction,
      category: t.category,
      status: t.status,
      occurredAt: t.occurredAt,
      paymentMethod: t.paymentMethod,
      reference: 'REF-$ref',
      note: t.note,
    );
  }

  static const _refChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static const _everyday = <_Payee>[
    _Payee(
      'Green Basket Grocers',
      TransactionCategory.groceries,
      32000,
      240000,
      [PaymentMethod.upi, PaymentMethod.card],
    ),
    _Payee('Corner Kirana Store', TransactionCategory.groceries, 8000, 65000, [
      PaymentMethod.upi,
      PaymentMethod.cash,
    ]),
    _Payee('Brew & Bean Café', TransactionCategory.dining, 18000, 52000, [
      PaymentMethod.upi,
      PaymentMethod.card,
    ]),
    _Payee('Spice Route Kitchen', TransactionCategory.dining, 45000, 180000, [
      PaymentMethod.card,
      PaymentMethod.upi,
    ]),
    _Payee('Dosa Corner', TransactionCategory.dining, 9000, 32000, [
      PaymentMethod.upi,
      PaymentMethod.cash,
    ]),
    _Payee('Metro Card Recharge', TransactionCategory.transport, 20000, 50000, [
      PaymentMethod.upi,
    ]),
    _Payee('City Cab Rides', TransactionCategory.transport, 12000, 68000, [
      PaymentMethod.upi,
      PaymentMethod.wallet,
    ]),
    _Payee(
      'Highway Fuel Station',
      TransactionCategory.transport,
      100000,
      300000,
      [PaymentMethod.card],
    ),
    _Payee('CareWell Pharmacy', TransactionCategory.health, 15000, 120000, [
      PaymentMethod.upi,
      PaymentMethod.card,
    ]),
    _Payee('BookNook', TransactionCategory.shopping, 29900, 129900, [
      PaymentMethod.card,
      PaymentMethod.upi,
    ]),
  ];

  static const _occasional = <_Payee>[
    _Payee('Urban Threads', TransactionCategory.shopping, 149900, 599900, [
      PaymentMethod.card,
    ]),
    _Payee('Gadget Hub', TransactionCategory.shopping, 199900, 1499900, [
      PaymentMethod.card,
    ]),
    _Payee('Cinema City', TransactionCategory.entertainment, 45000, 120000, [
      PaymentMethod.card,
    ]),
    _Payee('Coastal Stay Hotel', TransactionCategory.travel, 450000, 1200000, [
      PaymentMethod.card,
    ]),
  ];
}

class _Payee {
  const _Payee(this.name, this.category, this.min, this.max, this.methods);
  final String name;
  final TransactionCategory category;
  final int min;
  final int max;
  final List<PaymentMethod> methods;
}

class _Draft {
  _Draft(
    this.day,
    this.hour,
    this.title,
    this.category,
    this.minor,
    this.method, {
    this.credit = false,
    this.status = TransactionStatus.completed,
    this.note,
  });

  final DateTime day;
  final int hour;
  final String title;
  final TransactionCategory category;
  final int minor;
  final PaymentMethod method;
  final bool credit;
  final TransactionStatus status;
  final String? note;
}
