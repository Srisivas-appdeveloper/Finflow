import 'package:intl/intl.dart';

import '../../domain/repositories/data_management_repository.dart';
import '../sources/finance_store.dart';

class DataManagementRepositoryImpl implements DataManagementRepository {
  DataManagementRepositoryImpl(this._store, this._changes);

  final FinanceStore _store;
  final DataChanges _changes;

  @override
  Future<void> clearAll() async {
    await _store.clearAll();
    _changes.notify();
  }

  @override
  Future<String> exportTransactionsCsv() async {
    final rows = await _store.transactions()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    final date = DateFormat('yyyy-MM-dd');
    final time = DateFormat('HH:mm');
    final buffer = StringBuffer()
      ..writeln(
        'date,time,title,type,amount,your_share,currency,category,status,'
        'payment_method,reference,note',
      );
    for (final t in rows) {
      buffer.writeln(
        [
          date.format(t.occurredAt),
          time.format(t.occurredAt),
          t.title,
          t.isCredit ? 'income' : 'expense',
          t.amount.major.toStringAsFixed(2),
          t.ownAmount.major.toStringAsFixed(2),
          t.amount.currencyCode,
          t.category.label,
          t.status.label,
          t.paymentMethod.label,
          t.reference ?? '',
          t.note ?? '',
        ].map(csvCell).join(','),
      );
    }
    return buffer.toString();
  }

  /// Quotes a CSV cell when needed. Text that a spreadsheet would treat as a
  /// formula (starting with = + - @) is prefixed with an apostrophe, so an
  /// exported payee name can never execute in Excel or Sheets.
  static String csvCell(String value) {
    var v = value;
    if (v.isNotEmpty &&
        '=+-@\t\r'.contains(v[0]) &&
        double.tryParse(v) == null) {
      v = "'$v";
    }
    if (v.contains(RegExp('[",\n\r]'))) {
      v = '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }
}
