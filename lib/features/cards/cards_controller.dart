import 'dart:async';

import 'package:get/get.dart';

import '../../core/state/view_state.dart';
import '../../core/utils/clock.dart';
import '../../domain/entities/card_bill.dart';
import '../../domain/entities/credit_card.dart';
import '../../domain/entities/emi_plan.dart';
import '../../domain/entities/money.dart';
import '../../domain/repositories/card_repository.dart';

/// Everything the Cards tab shows.
class CardsOverview {
  const CardsOverview({
    required this.cards,
    required this.bills,
    required this.emis,
    required this.now,
    required this.currencyCode,
  });

  final List<CreditCard> cards;
  final List<CardBill> bills;
  final List<EmiPlan> emis;
  final DateTime now;
  final String currencyCode;

  Map<String, CreditCard> get cardsById => {for (final c in cards) c.id: c};

  /// Bills with money still owed, soonest due first.
  List<CardBill> get openBills =>
      bills.where((b) => !b.isSettled).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  /// Total still owed across open bills (statement balances, not the live
  /// outstanding).
  Money get totalDue => openBills.fold(
    Money.zero(currencyCode: currencyCode),
    (sum, b) => sum + b.remaining,
  );

  int get overdueCount => openBills.where((b) => b.isOverdue(now)).length;

  List<EmiPlan> get activeEmis =>
      emis.where((e) => !e.isClosed && !e.isComplete(now)).toList();

  /// Sum of this month's instalments across active EMIs.
  Money get monthlyEmi => activeEmis.fold(
    Money.zero(currencyCode: currencyCode),
    (sum, e) => sum + e.instalment,
  );
}

class CardsController extends GetxController {
  CardsController(this._repository, this._clock, {required this.currencyCode});

  final CardRepository _repository;
  final AppClock _clock;
  final String currencyCode;

  final state = Rx<ViewState<CardsOverview>>(const ViewLoading());
  StreamSubscription<void>? _changes;

  @override
  void onInit() {
    super.onInit();
    load();
    _changes = _repository.changes.listen((_) => load(showLoading: false));
  }

  @override
  void onClose() {
    _changes?.cancel();
    super.onClose();
  }

  Future<void> load({bool showLoading = true}) async {
    if (showLoading) state.value = const ViewLoading();
    try {
      final cards = await _repository.cards();
      if (cards.isEmpty) {
        state.value = const ViewEmpty();
        return;
      }
      state.value = ViewData(
        CardsOverview(
          cards: cards,
          bills: await _repository.bills(),
          emis: await _repository.emis(),
          now: _clock.now(),
          currencyCode: currencyCode,
        ),
      );
    } catch (_) {
      state.value = const ViewError(
        'We couldn\'t load your cards. Please try again.',
      );
    }
  }
}

/// One card with its bills and EMIs.
class CardDetailsController extends GetxController {
  CardDetailsController(this._repository, this._clock, {required this.cardId});

  final CardRepository _repository;
  final AppClock _clock;
  final String cardId;

  final state = Rx<ViewState<CardsOverview>>(const ViewLoading());
  StreamSubscription<void>? _changes;

  /// True when the card no longer exists (e.g. deleted).
  final notFound = false.obs;

  CreditCard? get card => switch (state.value) {
    ViewData(:final data) => data.cards.first,
    _ => null,
  };

  @override
  void onInit() {
    super.onInit();
    load();
    _changes = _repository.changes.listen((_) => load(showLoading: false));
  }

  @override
  void onClose() {
    _changes?.cancel();
    super.onClose();
  }

  Future<void> load({bool showLoading = true}) async {
    if (showLoading) state.value = const ViewLoading();
    try {
      final card = await _repository.card(cardId);
      state.value = ViewData(
        CardsOverview(
          cards: [card],
          bills: await _repository.bills(cardId: cardId),
          emis: await _repository.emis(cardId: cardId),
          now: _clock.now(),
          currencyCode: card.creditLimit.currencyCode,
        ),
      );
    } on CardDataNotFoundException {
      notFound.value = true;
      state.value = const ViewError('This card no longer exists.');
    } catch (_) {
      state.value = const ViewError(
        'We couldn\'t load this card. Please try again.',
      );
    }
  }
}
