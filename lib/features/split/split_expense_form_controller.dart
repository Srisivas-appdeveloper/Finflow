import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/utils/clock.dart';
import '../../core/utils/money_input.dart';
import '../../domain/entities/money.dart';
import '../../domain/entities/split.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_category.dart';
import '../../domain/repositories/split_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/split_ledger.dart';

/// Add or edit one shared expense in a group. With [transactionId], an
/// existing spend is split instead of entering a new one.
class SplitExpenseFormController extends GetxController {
  SplitExpenseFormController(
    this._splits,
    this._transactions,
    this._clock, {
    required this.groupId,
    this.expenseId,
    this.transactionId,
    required this.currencyCode,
  });

  final SplitRepository _splits;
  final TransactionRepository _transactions;
  final AppClock _clock;
  final String groupId;
  final String? expenseId;
  final String? transactionId;
  final String currencyCode;

  final amount = TextEditingController();
  final title = TextEditingController();

  /// Per-person amounts for [SplitMode.amounts].
  final _personAmounts = <String, TextEditingController>{};

  final group = Rxn<SplitGroup>();
  final category = TransactionCategory.groceries.obs;
  late final occurredAt = _clock.now().obs;
  final paidBy = SplitMember.youId.obs;
  final method = PaymentMethod.upi.obs;
  final mode = SplitMode.equal.obs;

  /// Who shares the cost in [SplitMode.equal].
  final included = <String>{}.obs;

  /// Weights for [SplitMode.shares].
  final units = <String, int>{}.obs;

  /// Bumped when any amount field changes, so the preview recomputes.
  final _edits = 0.obs;

  final loading = true.obs;
  final saving = false.obs;
  final loadError = RxnString();
  final amountError = RxnString();
  final titleError = RxnString();
  final splitError = RxnString();

  bool get isEditing => expenseId != null;

  /// Spending categories the user can pick.
  List<TransactionCategory> get categories => [
    for (final c in TransactionCategory.spending)
      if (!c.isSystem && c.isIncome == false) c,
    TransactionCategory.other,
  ];

  List<String> get people => group.value?.everyoneIds ?? const [];

  TextEditingController personAmount(String id) =>
      _personAmounts.putIfAbsent(id, TextEditingController.new);

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  @override
  void onClose() {
    amount.dispose();
    title.dispose();
    for (final c in _personAmounts.values) {
      c.dispose();
    }
    super.onClose();
  }

  Future<void> _load() async {
    loading.value = true;
    try {
      final g = await _splits.group(groupId);
      group.value = g;
      included.addAll(g.everyoneIds);
      units.addAll({for (final id in g.everyoneIds) id: 1});

      if (expenseId != null) {
        final e = await _splits.expense(expenseId!);
        amount.text = moneyInputText(e.amount);
        title.text = e.title;
        category.value = e.category;
        occurredAt.value = e.occurredAt;
        paidBy.value = e.paidBy;
        mode.value = e.mode;
        included
          ..clear()
          ..addAll([for (final s in e.shares) s.memberId]);
        units.addAll({for (final id in g.everyoneIds) id: 0});
        for (final s in e.shares) {
          units[s.memberId] = s.units;
          personAmount(s.memberId).text = moneyInputText(s.amount);
        }
        final linked = await _splits.transactionFor(e.id);
        if (linked != null &&
            linked.paymentMethod != PaymentMethod.paidByOther) {
          method.value = linked.paymentMethod;
        }
      } else if (transactionId != null) {
        final t = await _transactions.getById(transactionId!);
        amount.text = moneyInputText(t.amount);
        title.text = t.title;
        if (categories.contains(t.category)) category.value = t.category;
        occurredAt.value = t.occurredAt;
        if (PaymentMethod.selectable.contains(t.paymentMethod)) {
          method.value = t.paymentMethod;
        }
      }
      _edits.value++;
    } on SplitNotFoundException {
      loadError.value = 'This group or expense no longer exists.';
    } on TransactionNotFoundException {
      loadError.value = 'This transaction no longer exists.';
    } catch (_) {
      loadError.value = 'We couldn\'t open this expense. Please try again.';
    } finally {
      loading.value = false;
    }
  }

  Money? get _total {
    _edits.value;
    final m = parseMoney(amount.text, currencyCode: currencyCode);
    return m == null || !m.isPositive ? null : m;
  }

  void onAmountChanged(String _) {
    amountError.value = null;
    splitError.value = null;
    _edits.value++;
  }

  void onTitleChanged(String _) => titleError.value = null;

  void onPersonAmountChanged(String _) {
    splitError.value = null;
    _edits.value++;
  }

  void setMode(SplitMode value) {
    if (value == mode.value) return;
    // Start "by amount" from the split shown so far, so only the
    // differences need typing.
    if (value == SplitMode.amounts) {
      final current = shares();
      for (final id in people) {
        final m = current[id];
        personAmount(id).text = m == null ? '' : moneyInputText(m);
      }
      _edits.value++;
    }
    mode.value = value;
    splitError.value = null;
  }

  void toggle(String id) {
    splitError.value = null;
    included.contains(id) ? included.remove(id) : included.add(id);
  }

  void setUnits(String id, int value) {
    splitError.value = null;
    units[id] = value.clamp(0, 99);
  }

  /// Each person's part with the current inputs (empty until an amount is
  /// entered). In [SplitMode.amounts] these are what was typed.
  Map<String, Money> shares() {
    _edits.value;
    final total = _total;
    if (total == null && mode.value != SplitMode.amounts) return const {};
    return switch (mode.value) {
      SplitMode.equal => SplitCalculator.equal(total!, [
        for (final id in people)
          if (included.contains(id)) id,
      ]),
      SplitMode.shares => SplitCalculator.byShares(total!, {
        for (final id in people) id: units[id] ?? 0,
      }),
      SplitMode.amounts => {
        for (final id in people)
          if (parseMoney(personAmount(id).text, currencyCode: currencyCode)
              case final m? when m.isPositive)
            id: m,
      },
    };
  }

  /// In [SplitMode.amounts]: total minus what is assigned (negative when
  /// over). Null when no total is entered.
  Money? get unassigned {
    final total = _total;
    if (total == null) return null;
    return shares().values.fold<Money>(total, (left, m) => left - m);
  }

  bool _validate() {
    final total = _total;
    amountError.value = total == null
        ? 'Enter an amount greater than zero'
        : null;
    titleError.value = title.text.trim().isEmpty ? 'What was it for?' : null;
    final parts = shares();
    splitError.value = switch (mode.value) {
      _ when total == null => null,
      SplitMode.equal when parts.isEmpty => 'Choose who shares this',
      SplitMode.shares when parts.isEmpty => 'Give someone at least 1 share',
      SplitMode.amounts when !unassigned!.isZero =>
        'The amounts must add up to the total',
      _ => null,
    };
    return amountError.value == null &&
        titleError.value == null &&
        splitError.value == null;
  }

  /// Saves and returns the stored expense, or null if invalid.
  Future<SplitExpense?> save() async {
    if (!_validate()) return null;
    saving.value = true;
    try {
      final parts = shares();
      final draft = SplitExpense(
        id: expenseId ?? '',
        groupId: groupId,
        title: title.text,
        amount: _total!,
        category: category.value,
        paidBy: paidBy.value,
        mode: mode.value,
        shares: [
          for (final id in people)
            if (parts[id] case final m?)
              SplitShare(
                memberId: id,
                amount: m,
                units: mode.value == SplitMode.shares ? units[id] ?? 1 : 1,
              ),
        ],
        occurredAt: occurredAt.value,
      );
      return await _splits.saveExpense(
        draft,
        method: paidBy.value == SplitMember.youId ? method.value : null,
        transactionId: transactionId,
      );
    } finally {
      saving.value = false;
    }
  }
}
