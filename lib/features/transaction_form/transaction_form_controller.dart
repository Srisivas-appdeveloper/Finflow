import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/utils/clock.dart';
import '../../core/utils/money_input.dart';
import '../../domain/entities/money.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_category.dart';
import '../../domain/repositories/transaction_repository.dart';

/// Add or edit one transaction. When [editingId] is set, the existing
/// record is loaded and replaced on save.
class TransactionFormController extends GetxController {
  TransactionFormController(
    this._repository,
    this._clock, {
    this.editingId,
    required this.currencyCode,
  });

  final TransactionRepository _repository;
  final AppClock _clock;
  final String? editingId;
  final String currencyCode;

  final amount = TextEditingController();
  final title = TextEditingController();
  final note = TextEditingController();

  final direction = TransactionDirection.debit.obs;
  final category = TransactionCategory.dining.obs;
  final method = PaymentMethod.upi.obs;
  final status = TransactionStatus.completed.obs;
  late final occurredAt = _clock.now().obs;

  final loading = false.obs;
  final saving = false.obs;
  final amountError = RxnString();
  final titleError = RxnString();

  Transaction? _original;

  bool get isEditing => editingId != null;

  /// A payment recorded against a card bill. Its type and category are
  /// fixed: they are what make it settle the bill instead of counting as
  /// spending.
  bool get isBillPayment => _original?.billId != null;

  /// Bill payments and split settlements keep their type and category.
  bool get isLockedType =>
      isBillPayment || (_original?.category.isSystem ?? false);

  /// Categories offered for the selected direction. Card bill payments and
  /// split settlements are only created from a bill or a group (so they
  /// stay linked to it).
  List<TransactionCategory> get categories {
    final original = _original?.category;
    if (isLockedType) return [original!];
    final base = direction.value == TransactionDirection.credit
        ? TransactionCategory.income
        : TransactionCategory.spending;
    return [
      for (final c in base)
        if (!c.isSystem) c,
    ];
  }

  /// Turn the new spend into a split once saved.
  final splitAfterSave = false.obs;

  /// Splitting is offered for new spending only; existing spends are split
  /// from their details page.
  bool get canSplit =>
      !isEditing && direction.value == TransactionDirection.debit;

  @override
  void onInit() {
    super.onInit();
    if (isEditing) _load();
  }

  @override
  void onClose() {
    amount.dispose();
    title.dispose();
    note.dispose();
    super.onClose();
  }

  Future<void> _load() async {
    loading.value = true;
    try {
      final t = await _repository.getById(editingId!);
      _original = t;
      amount.text = moneyInputText(t.amount);
      title.text = t.title;
      note.text = t.note ?? '';
      direction.value = t.direction;
      category.value = t.category;
      method.value = t.paymentMethod;
      status.value = t.status;
      occurredAt.value = t.occurredAt;
    } finally {
      loading.value = false;
    }
  }

  /// Clear a field's error as soon as the user edits it.
  void onAmountChanged(String _) => amountError.value = null;
  void onTitleChanged(String _) => titleError.value = null;

  void setDirection(TransactionDirection value) {
    direction.value = value;
    titleError.value = null;
    if (!categories.contains(category.value)) {
      category.value = value == TransactionDirection.credit
          ? TransactionCategory.salary
          : TransactionCategory.dining;
    }
  }

  bool validate() {
    final money = parseMoney(amount.text, currencyCode: currencyCode);
    amountError.value = money == null || !money.isPositive
        ? 'Enter an amount greater than zero'
        : null;
    titleError.value = title.text.trim().isEmpty
        ? (direction.value == TransactionDirection.credit
              ? 'Who paid you?'
              : 'Who did you pay?')
        : null;
    return amountError.value == null && titleError.value == null;
  }

  /// Keeps the user's share of an earlier split, capped at the new amount.
  Money? _shareFor(Money amount) {
    final share = _original?.share;
    if (share == null) return null;
    return share.minor > amount.minor ? amount : share;
  }

  /// Saves and returns the stored transaction, or null if invalid.
  Future<Transaction?> save() async {
    if (!validate()) return null;
    saving.value = true;
    try {
      final money = parseMoney(amount.text, currencyCode: currencyCode)!;
      final draft = Transaction(
        id: editingId ?? '',
        title: title.text,
        amount: money,
        direction: direction.value,
        category: category.value,
        status: status.value,
        occurredAt: occurredAt.value,
        paymentMethod: method.value,
        reference: _original?.reference,
        note: note.text,
        billId: _original?.billId,
        share: _shareFor(money),
        splitId: _original?.splitId,
      );
      return isEditing
          ? await _repository.update(draft)
          : await _repository.add(draft);
    } finally {
      saving.value = false;
    }
  }
}
