import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' hide Transaction;

import '../../domain/entities/card_bill.dart';
import '../../domain/entities/credit_card.dart';
import '../../domain/entities/emi_plan.dart';
import '../../domain/entities/money.dart';
import '../../domain/entities/split.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_category.dart';
import 'finance_store.dart';

/// [FinanceStore] backed by an on-device SQLite database.
///
/// Amounts are stored as integer minor units; dates as milliseconds since
/// the epoch (local time); enums by name, so reordering enum values never
/// corrupts stored data. Unknown enum names fall back to safe defaults.
class SqliteFinanceStore implements FinanceStore {
  SqliteFinanceStore._(this._db);

  static const fileName = 'finflow.db';
  static const schemaVersion = 2;

  final Database _db;

  /// Opens (creating or migrating) the app database.
  static Future<SqliteFinanceStore> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), fileName);
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => _migrate(db, 0, version),
        onUpgrade: _migrate,
      ),
    );
    return SqliteFinanceStore._(db);
  }

  Future<void> close() => _db.close();

  /// Schema migrations, applied in order. Add a new `if (from < n)` block
  /// for each future schema version; never edit an existing one.
  static Future<void> _migrate(Database db, int from, int to) async {
    if (from < 1) {
      final batch = db.batch()
        ..execute('''
          CREATE TABLE transactions (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            amount_minor INTEGER NOT NULL,
            currency TEXT NOT NULL,
            direction TEXT NOT NULL,
            category TEXT NOT NULL,
            status TEXT NOT NULL,
            occurred_at INTEGER NOT NULL,
            payment_method TEXT NOT NULL,
            reference TEXT,
            note TEXT,
            bill_id TEXT
          )''')
        ..execute(
          'CREATE INDEX idx_transactions_occurred ON transactions(occurred_at)',
        )
        ..execute('CREATE INDEX idx_transactions_bill ON transactions(bill_id)')
        ..execute('''
          CREATE TABLE cards (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            issuer TEXT NOT NULL,
            last4 TEXT,
            limit_minor INTEGER NOT NULL,
            currency TEXT NOT NULL,
            statement_day INTEGER NOT NULL,
            due_day INTEGER NOT NULL,
            outstanding_minor INTEGER,
            outstanding_updated_at INTEGER,
            style_index INTEGER NOT NULL DEFAULT 0
          )''')
        ..execute('''
          CREATE TABLE bills (
            id TEXT PRIMARY KEY,
            card_id TEXT NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
            statement_date INTEGER NOT NULL,
            due_date INTEGER NOT NULL,
            total_minor INTEGER NOT NULL,
            minimum_minor INTEGER NOT NULL,
            currency TEXT NOT NULL,
            UNIQUE (card_id, statement_date)
          )''')
        ..execute('''
          CREATE TABLE emis (
            id TEXT PRIMARY KEY,
            card_id TEXT REFERENCES cards(id) ON DELETE CASCADE,
            title TEXT NOT NULL,
            principal_minor INTEGER NOT NULL,
            instalment_minor INTEGER NOT NULL,
            currency TEXT NOT NULL,
            tenure_months INTEGER NOT NULL,
            first_due_date INTEGER NOT NULL,
            annual_rate REAL,
            fee_minor INTEGER,
            closed_on INTEGER
          )''');
      await batch.commit(noResult: true);
    }
    if (from < 2) {
      // Splits. Transactions gain the user's share of a split spend and a
      // link to the split record they mirror.
      final batch = db.batch()
        ..execute('ALTER TABLE transactions ADD COLUMN share_minor INTEGER')
        ..execute('ALTER TABLE transactions ADD COLUMN split_id TEXT')
        ..execute(
          'CREATE INDEX idx_transactions_split ON transactions(split_id)',
        )
        ..execute('''
          CREATE TABLE split_groups (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )''')
        ..execute('''
          CREATE TABLE split_members (
            id TEXT PRIMARY KEY,
            group_id TEXT NOT NULL
              REFERENCES split_groups(id) ON DELETE CASCADE,
            name TEXT NOT NULL,
            position INTEGER NOT NULL
          )''')
        ..execute('''
          CREATE TABLE split_expenses (
            id TEXT PRIMARY KEY,
            group_id TEXT NOT NULL
              REFERENCES split_groups(id) ON DELETE CASCADE,
            title TEXT NOT NULL,
            amount_minor INTEGER NOT NULL,
            currency TEXT NOT NULL,
            category TEXT NOT NULL,
            paid_by TEXT NOT NULL,
            mode TEXT NOT NULL,
            occurred_at INTEGER NOT NULL
          )''')
        ..execute('''
          CREATE TABLE split_shares (
            expense_id TEXT NOT NULL
              REFERENCES split_expenses(id) ON DELETE CASCADE,
            member_id TEXT NOT NULL,
            amount_minor INTEGER NOT NULL,
            units INTEGER NOT NULL,
            position INTEGER NOT NULL,
            PRIMARY KEY (expense_id, member_id)
          )''')
        ..execute('''
          CREATE TABLE split_settlements (
            id TEXT PRIMARY KEY,
            group_id TEXT NOT NULL
              REFERENCES split_groups(id) ON DELETE CASCADE,
            from_id TEXT NOT NULL,
            to_id TEXT NOT NULL,
            amount_minor INTEGER NOT NULL,
            currency TEXT NOT NULL,
            occurred_at INTEGER NOT NULL
          )''');
      await batch.commit(noResult: true);
    }
  }

  // --- Mapping ---------------------------------------------------------------

  static int _ms(DateTime d) => d.millisecondsSinceEpoch;
  static DateTime _date(Object? v) =>
      DateTime.fromMillisecondsSinceEpoch(v! as int);
  static DateTime? _dateOrNull(Object? v) => v == null ? null : _date(v);

  static T _enum<T extends Enum>(List<T> values, Object? name, T fallback) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  static Map<String, Object?> _txRow(Transaction t) => {
    'id': t.id,
    'title': t.title,
    'amount_minor': t.amount.minor,
    'currency': t.amount.currencyCode,
    'direction': t.direction.name,
    'category': t.category.name,
    'status': t.status.name,
    'occurred_at': _ms(t.occurredAt),
    'payment_method': t.paymentMethod.name,
    'reference': t.reference,
    'note': t.note,
    'bill_id': t.billId,
    'share_minor': t.share?.minor,
    'split_id': t.splitId,
  };

  static Transaction _tx(Map<String, Object?> r) {
    final currency = r['currency']! as String;
    final share = r['share_minor'] as int?;
    return Transaction(
      id: r['id']! as String,
      title: r['title']! as String,
      amount: Money(r['amount_minor']! as int, currencyCode: currency),
      direction: _enum(
        TransactionDirection.values,
        r['direction'],
        TransactionDirection.debit,
      ),
      category: _enum(
        TransactionCategory.values,
        r['category'],
        TransactionCategory.other,
      ),
      status: _enum(
        TransactionStatus.values,
        r['status'],
        TransactionStatus.completed,
      ),
      occurredAt: _date(r['occurred_at']),
      paymentMethod: _enum(
        PaymentMethod.values,
        r['payment_method'],
        PaymentMethod.cash,
      ),
      reference: r['reference'] as String?,
      note: r['note'] as String?,
      billId: r['bill_id'] as String?,
      share: share == null ? null : Money(share, currencyCode: currency),
      splitId: r['split_id'] as String?,
    );
  }

  static Map<String, Object?> _cardRow(CreditCard c) => {
    'id': c.id,
    'name': c.name,
    'issuer': c.issuer,
    'last4': c.last4,
    'limit_minor': c.creditLimit.minor,
    'currency': c.creditLimit.currencyCode,
    'statement_day': c.statementDay,
    'due_day': c.dueDay,
    'outstanding_minor': c.currentOutstanding?.minor,
    'outstanding_updated_at': c.outstandingUpdatedAt == null
        ? null
        : _ms(c.outstandingUpdatedAt!),
    'style_index': c.styleIndex,
  };

  static CreditCard _card(Map<String, Object?> r) {
    final currency = r['currency']! as String;
    final outstanding = r['outstanding_minor'] as int?;
    return CreditCard(
      id: r['id']! as String,
      name: r['name']! as String,
      issuer: r['issuer']! as String,
      last4: r['last4'] as String?,
      creditLimit: Money(r['limit_minor']! as int, currencyCode: currency),
      statementDay: r['statement_day']! as int,
      dueDay: r['due_day']! as int,
      currentOutstanding: outstanding == null
          ? null
          : Money(outstanding, currencyCode: currency),
      outstandingUpdatedAt: _dateOrNull(r['outstanding_updated_at']),
      styleIndex: r['style_index']! as int,
    );
  }

  static Map<String, Object?> _billRow(CardBill b) => {
    'id': b.id,
    'card_id': b.cardId,
    'statement_date': _ms(b.statementDate),
    'due_date': _ms(b.dueDate),
    'total_minor': b.totalDue.minor,
    'minimum_minor': b.minimumDue.minor,
    'currency': b.totalDue.currencyCode,
  };

  static CardBill _bill(Map<String, Object?> r) {
    final currency = r['currency']! as String;
    return CardBill(
      id: r['id']! as String,
      cardId: r['card_id']! as String,
      statementDate: _date(r['statement_date']),
      dueDate: _date(r['due_date']),
      totalDue: Money(r['total_minor']! as int, currencyCode: currency),
      minimumDue: Money(r['minimum_minor']! as int, currencyCode: currency),
      paid: Money.zero(currencyCode: currency),
    );
  }

  static Map<String, Object?> _emiRow(EmiPlan e) => {
    'id': e.id,
    'card_id': e.cardId,
    'title': e.title,
    'principal_minor': e.principal.minor,
    'instalment_minor': e.instalment.minor,
    'currency': e.instalment.currencyCode,
    'tenure_months': e.tenureMonths,
    'first_due_date': _ms(e.firstDueDate),
    'annual_rate': e.annualInterestRate,
    'fee_minor': e.processingFee?.minor,
    'closed_on': e.closedOn == null ? null : _ms(e.closedOn!),
  };

  static EmiPlan _emi(Map<String, Object?> r) {
    final currency = r['currency']! as String;
    final fee = r['fee_minor'] as int?;
    return EmiPlan(
      id: r['id']! as String,
      cardId: r['card_id'] as String?,
      title: r['title']! as String,
      principal: Money(r['principal_minor']! as int, currencyCode: currency),
      instalment: Money(r['instalment_minor']! as int, currencyCode: currency),
      tenureMonths: r['tenure_months']! as int,
      firstDueDate: _date(r['first_due_date']),
      annualInterestRate: (r['annual_rate'] as num?)?.toDouble(),
      processingFee: fee == null ? null : Money(fee, currencyCode: currency),
      closedOn: _dateOrNull(r['closed_on']),
    );
  }

  static Map<String, Object?> _expenseRow(SplitExpense e) => {
    'id': e.id,
    'group_id': e.groupId,
    'title': e.title,
    'amount_minor': e.amount.minor,
    'currency': e.amount.currencyCode,
    'category': e.category.name,
    'paid_by': e.paidBy,
    'mode': e.mode.name,
    'occurred_at': _ms(e.occurredAt),
  };

  static SplitExpense _expense(
    Map<String, Object?> r,
    List<SplitShare> shares,
  ) {
    final currency = r['currency']! as String;
    return SplitExpense(
      id: r['id']! as String,
      groupId: r['group_id']! as String,
      title: r['title']! as String,
      amount: Money(r['amount_minor']! as int, currencyCode: currency),
      category: _enum(
        TransactionCategory.values,
        r['category'],
        TransactionCategory.other,
      ),
      paidBy: r['paid_by']! as String,
      mode: _enum(SplitMode.values, r['mode'], SplitMode.amounts),
      shares: [
        for (final s in shares)
          SplitShare(
            memberId: s.memberId,
            amount: Money(s.amount.minor, currencyCode: currency),
            units: s.units,
          ),
      ],
      occurredAt: _date(r['occurred_at']),
    );
  }

  static Map<String, Object?> _settlementRow(SplitSettlement s) => {
    'id': s.id,
    'group_id': s.groupId,
    'from_id': s.fromId,
    'to_id': s.toId,
    'amount_minor': s.amount.minor,
    'currency': s.amount.currencyCode,
    'occurred_at': _ms(s.occurredAt),
  };

  static SplitSettlement _settlement(Map<String, Object?> r) => SplitSettlement(
    id: r['id']! as String,
    groupId: r['group_id']! as String,
    fromId: r['from_id']! as String,
    toId: r['to_id']! as String,
    amount: Money(
      r['amount_minor']! as int,
      currencyCode: r['currency']! as String,
    ),
    occurredAt: _date(r['occurred_at']),
  );

  /// Writes the group row and replaces its member list.
  static Future<void> _writeGroup(DatabaseExecutor db, SplitGroup g) async {
    await _upsert(db, 'split_groups', {
      'id': g.id,
      'name': g.name,
      'created_at': _ms(g.createdAt),
    });
    await db.delete('split_members', where: 'group_id = ?', whereArgs: [g.id]);
    for (var i = 0; i < g.members.length; i++) {
      await db.insert('split_members', {
        'id': g.members[i].id,
        'group_id': g.id,
        'name': g.members[i].name,
        'position': i,
      });
    }
  }

  /// Writes the expense row and replaces its shares.
  static Future<void> _writeExpense(DatabaseExecutor db, SplitExpense e) async {
    await _upsert(db, 'split_expenses', _expenseRow(e));
    await db.delete('split_shares', where: 'expense_id = ?', whereArgs: [e.id]);
    for (var i = 0; i < e.shares.length; i++) {
      final share = e.shares[i];
      await db.insert('split_shares', {
        'expense_id': e.id,
        'member_id': share.memberId,
        'amount_minor': share.amount.minor,
        'units': share.units,
        'position': i,
      });
    }
  }

  // --- FinanceStore ---------------------------------------------------------

  /// Inserts [row] or updates the existing row with the same id.
  ///
  /// Never use `ConflictAlgorithm.replace` here: SQLite implements REPLACE
  /// as delete-then-insert, and deleting a card would cascade to its bills
  /// and EMIs. (`ON CONFLICT DO UPDATE` is avoided because it needs SQLite
  /// 3.24, newer than some supported Android versions ship.)
  static Future<void> _upsert(
    DatabaseExecutor db,
    String table,
    Map<String, Object?> row,
  ) async {
    final updated = await db.update(
      table,
      row,
      where: 'id = ?',
      whereArgs: [row['id']],
    );
    if (updated == 0) await db.insert(table, row);
  }

  @override
  Future<List<Transaction>> transactions() async => (await _db.query(
    'transactions',
    orderBy: 'occurred_at DESC',
  )).map(_tx).toList();

  @override
  Future<void> putTransaction(Transaction t) =>
      _upsert(_db, 'transactions', _txRow(t));

  @override
  Future<void> deleteTransaction(String id) =>
      _db.delete('transactions', where: 'id = ?', whereArgs: [id]);

  @override
  Future<List<CreditCard>> cards() async =>
      (await _db.query('cards', orderBy: 'name')).map(_card).toList();

  @override
  Future<void> putCard(CreditCard c) => _upsert(_db, 'cards', _cardRow(c));

  @override
  Future<void> deleteCard(String id) =>
      _db.delete('cards', where: 'id = ?', whereArgs: [id]);

  @override
  Future<List<CardBill>> bills() async => (await _db.query(
    'bills',
    orderBy: 'statement_date DESC',
  )).map(_bill).toList();

  @override
  Future<void> putBill(CardBill b) => _upsert(_db, 'bills', _billRow(b));

  @override
  Future<void> deleteBill(String id) =>
      _db.delete('bills', where: 'id = ?', whereArgs: [id]);

  @override
  Future<List<EmiPlan>> emis() async =>
      (await _db.query('emis', orderBy: 'first_due_date')).map(_emi).toList();

  @override
  Future<void> putEmi(EmiPlan e) => _upsert(_db, 'emis', _emiRow(e));

  @override
  Future<void> deleteEmi(String id) =>
      _db.delete('emis', where: 'id = ?', whereArgs: [id]);

  @override
  Future<List<SplitGroup>> splitGroups() async {
    final members = <String, List<SplitMember>>{};
    for (final r in await _db.query('split_members', orderBy: 'position')) {
      (members[r['group_id']! as String] ??= []).add(
        SplitMember(id: r['id']! as String, name: r['name']! as String),
      );
    }
    return [
      for (final r in await _db.query('split_groups', orderBy: 'created_at'))
        SplitGroup(
          id: r['id']! as String,
          name: r['name']! as String,
          members: members[r['id']] ?? const [],
          createdAt: _date(r['created_at']),
        ),
    ];
  }

  @override
  Future<void> putSplitGroup(SplitGroup group) =>
      _db.transaction((txn) => _writeGroup(txn, group));

  @override
  Future<void> deleteSplitGroup(String id) =>
      _db.delete('split_groups', where: 'id = ?', whereArgs: [id]);

  @override
  Future<List<SplitExpense>> splitExpenses() async {
    final shares = <String, List<SplitShare>>{};
    for (final r in await _db.query(
      'split_shares',
      orderBy: 'expense_id, position',
    )) {
      (shares[r['expense_id']! as String] ??= []).add(
        SplitShare(
          memberId: r['member_id']! as String,
          // Currency is the expense's; applied in [_expense].
          amount: Money(r['amount_minor']! as int),
          units: r['units']! as int,
        ),
      );
    }
    return [
      for (final r in await _db.query(
        'split_expenses',
        orderBy: 'occurred_at DESC',
      ))
        _expense(r, shares[r['id']] ?? const []),
    ];
  }

  @override
  Future<void> putSplitExpense(SplitExpense expense) =>
      _db.transaction((txn) => _writeExpense(txn, expense));

  @override
  Future<void> deleteSplitExpense(String id) =>
      _db.delete('split_expenses', where: 'id = ?', whereArgs: [id]);

  @override
  Future<List<SplitSettlement>> splitSettlements() async => (await _db.query(
    'split_settlements',
    orderBy: 'occurred_at DESC',
  )).map(_settlement).toList();

  @override
  Future<void> putSplitSettlement(SplitSettlement settlement) =>
      _upsert(_db, 'split_settlements', _settlementRow(settlement));

  @override
  Future<void> deleteSplitSettlement(String id) =>
      _db.delete('split_settlements', where: 'id = ?', whereArgs: [id]);

  @override
  Future<void> putAll({
    List<Transaction> transactions = const [],
    List<CreditCard> cards = const [],
    List<CardBill> bills = const [],
    List<EmiPlan> emis = const [],
    List<SplitGroup> splitGroups = const [],
    List<SplitExpense> splitExpenses = const [],
    List<SplitSettlement> splitSettlements = const [],
  }) {
    return _db.transaction((txn) async {
      for (final g in splitGroups) {
        await _writeGroup(txn, g);
      }
      for (final e in splitExpenses) {
        await _writeExpense(txn, e);
      }
      for (final s in splitSettlements) {
        await _upsert(txn, 'split_settlements', _settlementRow(s));
      }
      for (final c in cards) {
        await _upsert(txn, 'cards', _cardRow(c));
      }
      for (final b in bills) {
        await _upsert(txn, 'bills', _billRow(b));
      }
      for (final e in emis) {
        await _upsert(txn, 'emis', _emiRow(e));
      }
      for (final t in transactions) {
        await _upsert(txn, 'transactions', _txRow(t));
      }
    });
  }

  @override
  Future<void> clearAll() {
    return _db.transaction((txn) async {
      final batch = txn.batch()
        ..delete('transactions')
        ..delete('emis')
        ..delete('bills')
        ..delete('cards')
        ..delete('split_shares')
        ..delete('split_expenses')
        ..delete('split_settlements')
        ..delete('split_members')
        ..delete('split_groups');
      await batch.commit(noResult: true);
    });
  }
}
