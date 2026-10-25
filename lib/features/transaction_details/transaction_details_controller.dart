import 'package:get/get.dart';

import '../../core/state/view_state.dart';
import '../../domain/entities/split.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_category.dart';
import '../../domain/repositories/split_repository.dart';
import '../../domain/repositories/transaction_repository.dart';

/// The group record a split transaction mirrors.
class SplitLink {
  const SplitLink({required this.group, this.expense, this.settlement});

  final SplitGroup group;
  final SplitExpense? expense;
  final SplitSettlement? settlement;
}

class TransactionDetailsController extends GetxController {
  TransactionDetailsController(
    this._repository,
    this._splits, {
    required this.id,
    Transaction? initial,
    this.heroTag,
  }) : state = Rx<ViewState<Transaction>>(
         initial != null ? ViewData(initial) : const ViewLoading(),
       );

  final TransactionRepository _repository;
  final SplitRepository _splits;
  final String id;
  final Object? heroTag;

  final Rx<ViewState<Transaction>> state;
  final saving = false.obs;

  /// True when the transaction no longer exists (e.g. deleted elsewhere).
  final notFound = false.obs;

  /// For split transactions: the group and record behind it.
  final split = Rxn<SplitLink>();

  Transaction? get transaction => switch (state.value) {
    ViewData(:final data) => data,
    _ => null,
  };

  @override
  void onInit() {
    super.onInit();
    // Always confirm against the repository; when navigation passed the
    // transaction along, this happens without showing a loading state.
    load(showLoading: transaction == null);
  }

  Future<void> load({bool showLoading = true}) async {
    if (showLoading) state.value = const ViewLoading();
    try {
      final t = await _repository.getById(id);
      state.value = ViewData(t);
      split.value = await _linkFor(t);
    } on TransactionNotFoundException {
      notFound.value = true;
      state.value = const ViewError('This transaction is no longer available.');
    } catch (_) {
      if (transaction == null) {
        state.value = const ViewError(
          'We couldn\'t load this transaction. Please try again.',
        );
      }
    }
  }

  Future<SplitLink?> _linkFor(Transaction t) async {
    final splitId = t.splitId;
    if (splitId == null) return null;
    try {
      for (final e in await _splits.expenses()) {
        if (e.id == splitId) {
          return SplitLink(group: await _splits.group(e.groupId), expense: e);
        }
      }
      for (final s in await _splits.settlements()) {
        if (s.id == splitId) {
          return SplitLink(
            group: await _splits.group(s.groupId),
            settlement: s,
          );
        }
      }
    } on SplitNotFoundException {
      // The group was deleted; the transaction stands on its own.
    }
    return null;
  }

  /// A spend that can still be split with a group.
  bool get canSplit {
    final t = transaction;
    return t != null &&
        t.isDebit &&
        !t.isSplit &&
        t.billId == null &&
        !t.category.isSystem &&
        t.status != TransactionStatus.failed;
  }

  /// Categories that make sense for this transaction's direction. Card
  /// bill payments and split settlements are only created by the app, so
  /// they are not offered here.
  List<TransactionCategory> get categoryOptions => [
    for (final c
        in transaction?.isCredit ?? false
            ? TransactionCategory.income
            : TransactionCategory.spending)
      if (!c.isSystem) c,
  ];

  /// Bill payments keep their category (it is what links them to the
  /// bill); split transactions follow their group expense.
  bool get canChangeCategory {
    final t = transaction;
    return t != null && t.billId == null && !t.isSplit && !t.category.isSystem;
  }

  /// Returns `true` on success.
  Future<bool> changeCategory(TransactionCategory category) async {
    final current = transaction;
    if (current == null || current.category == category) return true;
    saving.value = true;
    try {
      state.value = ViewData(await _repository.updateCategory(id, category));
      return true;
    } catch (_) {
      return false;
    } finally {
      saving.value = false;
    }
  }

  /// Deletes the transaction. Returns true on success.
  Future<bool> delete() async {
    try {
      await _repository.delete(id);
      return true;
    } catch (_) {
      return false;
    }
  }
}
