/// Whole-dataset operations: wiping and export.
abstract interface class DataManagementRepository {
  /// Deletes every stored record.
  Future<void> clearAll();

  /// All transactions as CSV text.
  Future<String> exportTransactionsCsv();
}
