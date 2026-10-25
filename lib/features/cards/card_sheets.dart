import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/config/app_environment.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money_input.dart';
import '../../domain/entities/card_bill.dart';
import '../../domain/entities/credit_card.dart';
import '../../domain/entities/emi_plan.dart';
import '../../domain/entities/money.dart';
import '../../domain/entities/transaction.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_inputs.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/selection.dart';
import 'widgets/card_widgets.dart';

String get _currency => Get.find<AppEnvironment>().currencyCode;
String get _symbol => Get.find<Formatters>().currencySymbol(_currency);

/// Shared save button for the sheets below.
Widget _saveButton(String label, VoidCallback onPressed) => AppButton(
  label: label,
  icon: Icons.check_rounded,
  expand: true,
  onPressed: onPressed,
);

// ---------------------------------------------------------------------------
// Card
// ---------------------------------------------------------------------------

/// Add or edit a card. Pops with the edited [CreditCard] (id empty for new).
class CardFormSheet extends StatefulWidget {
  const CardFormSheet({super.key, this.initial});

  final CreditCard? initial;

  @override
  State<CardFormSheet> createState() => _CardFormSheetState();
}

class _CardFormSheetState extends State<CardFormSheet> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _issuer = TextEditingController(text: widget.initial?.issuer);
  late final _last4 = TextEditingController(text: widget.initial?.last4);
  late final _limit = TextEditingController(
    text: widget.initial == null
        ? ''
        : moneyInputText(widget.initial!.creditLimit),
  );
  late int _statementDay = widget.initial?.statementDay ?? 1;
  late int _dueDay = widget.initial?.dueDay ?? 20;
  late int _style = widget.initial?.styleIndex ?? 0;
  String? _nameError;
  String? _limitError;
  String? _last4Error;

  @override
  void dispose() {
    _name.dispose();
    _issuer.dispose();
    _last4.dispose();
    _limit.dispose();
    super.dispose();
  }

  void _submit() {
    final limit = parseMoney(_limit.text, currencyCode: _currency);
    final last4 = _last4.text.trim();
    setState(() {
      _nameError = _name.text.trim().isEmpty ? 'Give the card a name' : null;
      _limitError = limit == null || !limit.isPositive
          ? 'Enter the credit limit'
          : null;
      _last4Error = last4.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(last4)
          ? 'Use the last 4 digits only'
          : null;
    });
    if (_nameError != null || _limitError != null || _last4Error != null) {
      return;
    }
    final base = widget.initial;
    Navigator.of(context).pop(
      CreditCard(
        id: base?.id ?? '',
        name: _name.text.trim(),
        issuer: _issuer.text.trim(),
        last4: last4.isEmpty ? null : last4,
        creditLimit: limit!,
        statementDay: _statementDay,
        dueDay: _dueDay,
        currentOutstanding: base?.currentOutstanding,
        outstandingUpdatedAt: base?.outstandingUpdatedAt,
        styleIndex: _style,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: widget.initial == null ? 'Add credit card' : 'Edit card',
      subtitle: 'Only what you need to track bills',
      icon: Icons.credit_card_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _name,
            label: 'Card name',
            hint: 'e.g. Travel card',
            prefixIcon: Icons.badge_outlined,
            errorText: _nameError,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _issuer,
            label: 'Bank or issuer (optional)',
            prefixIcon: Icons.account_balance_outlined,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _last4,
            label: 'Last 4 digits (optional)',
            helper: 'Never enter the full card number',
            prefixIcon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            errorText: _last4Error,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AmountField(
            controller: _limit,
            currencySymbol: _symbol,
            label: 'Credit limit',
            large: false,
            errorText: _limitError,
          ),
          FormSection(
            label: 'Billing cycle',
            child: Row(
              children: [
                Expanded(
                  child: DayOfMonthField(
                    label: 'Statement day',
                    value: _statementDay,
                    onChanged: (v) => setState(() => _statementDay = v),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: DayOfMonthField(
                    label: 'Due day',
                    value: _dueDay,
                    onChanged: (v) => setState(() => _dueDay = v),
                  ),
                ),
              ],
            ),
          ),
          FormSection(
            label: 'Look',
            child: Row(
              children: [
                for (var i = 0; i < CardStyles.gradients.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: Semantics(
                      button: true,
                      selected: _style == i,
                      label: 'Card colour ${i + 1}',
                      child: GestureDetector(
                        onTap: () => setState(() => _style = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 48,
                          height: 32,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: CardStyles.of(i),
                            border: Border.all(
                              color: _style == i
                                  ? context.colors.onSurface
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: _saveButton(
        widget.initial == null ? 'Add card' : 'Save card',
        _submit,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Outstanding balance
// ---------------------------------------------------------------------------

/// Update the card's current outstanding. Pops with the amount, or a zero
/// amount with `clear` semantics handled by the caller.
class OutstandingSheet extends StatefulWidget {
  const OutstandingSheet({super.key, required this.card});

  final CreditCard card;

  @override
  State<OutstandingSheet> createState() => _OutstandingSheetState();
}

class _OutstandingSheetState extends State<OutstandingSheet> {
  late final _amount = TextEditingController(
    text: widget.card.currentOutstanding == null
        ? ''
        : moneyInputText(widget.card.currentOutstanding!),
  );
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final value = parseMoney(_amount.text, currencyCode: _currency);
    if (value == null) {
      setState(() => _error = 'Enter the amount shown in your bank app');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: 'Current outstanding',
      subtitle: 'Everything owed on the card right now',
      icon: Icons.account_balance_wallet_outlined,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This is different from the statement balance: it includes '
            'purchases since the last statement. Copy it from your bank app; '
            'it is used to show your available limit.',
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          AmountField(
            controller: _amount,
            currencySymbol: _symbol,
            label: 'Outstanding today',
            errorText: _error,
          ),
        ],
      ),
      actions: _saveButton('Update', _submit),
    );
  }
}

// ---------------------------------------------------------------------------
// Bill
// ---------------------------------------------------------------------------

/// Add or edit a bill (statement) for [card]. Pops with a [CardBill].
class BillFormSheet extends StatefulWidget {
  const BillFormSheet({
    super.key,
    required this.card,
    required this.now,
    this.initial,
    this.takenStatementDates = const {},
  });

  final CreditCard card;
  final DateTime now;
  final CardBill? initial;

  /// Statement dates that already have a bill on this card (excluding the
  /// one being edited); the same statement cannot be entered twice.
  final Set<DateTime> takenStatementDates;

  @override
  State<BillFormSheet> createState() => _BillFormSheetState();
}

class _BillFormSheetState extends State<BillFormSheet> {
  late final _total = TextEditingController(
    text: widget.initial == null
        ? ''
        : moneyInputText(widget.initial!.totalDue),
  );
  late final _minimum = TextEditingController(
    text: widget.initial == null
        ? ''
        : moneyInputText(widget.initial!.minimumDue),
  );
  late DateTime _statementDate =
      widget.initial?.statementDate ?? _lastStatementDate();
  late DateTime _dueDate = widget.initial?.dueDate ?? _dueAfter(_statementDate);
  String? _totalError;
  String? _minimumError;
  String? _dateError;

  /// Most recent statement date implied by the card's statement day.
  DateTime _lastStatementDate() {
    final n = widget.now;
    final day = widget.card.statementDay;
    final thisMonth = DateTime(n.year, n.month, day);
    return thisMonth.isAfter(n)
        ? DateTime(n.year, n.month - 1, day)
        : thisMonth;
  }

  /// First occurrence of the card's due day after [statement].
  DateTime _dueAfter(DateTime statement) {
    final day = widget.card.dueDay;
    final same = DateTime(statement.year, statement.month, day);
    return same.isAfter(statement)
        ? same
        : DateTime(statement.year, statement.month + 1, day);
  }

  @override
  void dispose() {
    _total.dispose();
    _minimum.dispose();
    super.dispose();
  }

  void _submit() {
    final total = parseMoney(_total.text, currencyCode: _currency);
    final minimum = _minimum.text.trim().isEmpty
        ? Money.zero(currencyCode: _currency)
        : parseMoney(_minimum.text, currencyCode: _currency);
    setState(() {
      _totalError = total == null ? 'Enter the total amount due' : null;
      _minimumError = minimum == null
          ? 'Enter a valid amount'
          : total != null && minimum.minor > total.minor
          ? 'Cannot be more than the total'
          : null;
      final statementDay = DateTime(
        _statementDate.year,
        _statementDate.month,
        _statementDate.day,
      );
      _dateError = widget.takenStatementDates.contains(statementDay)
          ? 'You already added the bill for this statement date'
          : _dueDate.isBefore(_statementDate)
          ? 'Due date must be after the statement date'
          : null;
    });
    if (_totalError != null || _minimumError != null || _dateError != null) {
      return;
    }
    Navigator.of(context).pop(
      CardBill(
        id: widget.initial?.id ?? '',
        cardId: widget.card.id,
        statementDate: _statementDate,
        dueDate: _dueDate,
        totalDue: total!,
        minimumDue: minimum!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: widget.initial == null ? 'Add bill' : 'Edit bill',
      subtitle: '${widget.card.name} · from your statement',
      icon: Icons.receipt_long_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          AmountField(
            controller: _total,
            currencySymbol: _symbol,
            label: 'Total amount due',
            errorText: _totalError,
          ),
          const SizedBox(height: AppSpacing.md),
          AmountField(
            controller: _minimum,
            currencySymbol: _symbol,
            label: 'Minimum amount due (optional)',
            large: false,
            errorText: _minimumError,
          ),
          FormSection(
            label: 'Dates',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DateField(
                  label: 'Statement date',
                  value: _statementDate,
                  onChanged: (v) => setState(() {
                    _statementDate = v;
                    if (_dueDate.isBefore(v)) _dueDate = _dueAfter(v);
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
                DateField(
                  label: 'Payment due date',
                  value: _dueDate,
                  onChanged: (v) => setState(() => _dueDate = v),
                ),
                if (_dateError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      _dateError!,
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: _saveButton(
        widget.initial == null ? 'Add bill' : 'Save bill',
        _submit,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Payment
// ---------------------------------------------------------------------------

class PaymentDraft {
  const PaymentDraft(this.amount, this.paidOn, this.method);
  final Money amount;
  final DateTime paidOn;
  final PaymentMethod method;
}

/// Record a payment towards [bill]. Pops with a [PaymentDraft].
class PaymentSheet extends StatefulWidget {
  const PaymentSheet({super.key, required this.bill, required this.now});

  final CardBill bill;
  final DateTime now;

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

enum _Preset { full, minimum, custom }

class _PaymentSheetState extends State<PaymentSheet> {
  late _Preset _preset = _Preset.full;
  late final _custom = TextEditingController();
  late DateTime _paidOn = widget.now;
  PaymentMethod _method = PaymentMethod.bankTransfer;
  String? _error;

  Money get _minimumLeft {
    final m = widget.bill.minimumDue - widget.bill.paid;
    return m.isNegative ? Money.zero(currencyCode: m.currencyCode) : m;
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = switch (_preset) {
      _Preset.full => widget.bill.remaining,
      _Preset.minimum => _minimumLeft,
      _Preset.custom => parseMoney(_custom.text, currencyCode: _currency),
    };
    if (amount == null || !amount.isPositive) {
      setState(() => _error = 'Enter an amount greater than zero');
      return;
    }
    Navigator.of(context).pop(PaymentDraft(amount, _paidOn, _method));
  }

  @override
  Widget build(BuildContext context) {
    final f = Get.find<Formatters>();
    final showMinimum = _minimumLeft.isPositive;
    return AppSheet(
      title: 'Record payment',
      subtitle: '${f.money(widget.bill.remaining)} left to pay',
      icon: Icons.credit_score_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          ChoiceRow(
            label: 'Full amount · ${f.money(widget.bill.remaining)}',
            selected: _preset == _Preset.full,
            onTap: () => setState(() => _preset = _Preset.full),
          ),
          if (showMinimum) ...[
            const SizedBox(height: AppSpacing.sm),
            ChoiceRow(
              label: 'Minimum due · ${f.money(_minimumLeft)}',
              selected: _preset == _Preset.minimum,
              onTap: () => setState(() => _preset = _Preset.minimum),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          ChoiceRow(
            label: 'Other amount',
            selected: _preset == _Preset.custom,
            onTap: () => setState(() => _preset = _Preset.custom),
          ),
          if (_preset == _Preset.custom) ...[
            const SizedBox(height: AppSpacing.md),
            AmountField(
              controller: _custom,
              currencySymbol: _symbol,
              errorText: _error,
            ),
          ],
          FormSection(
            label: 'Paid on',
            child: DateField(
              label: 'Payment date',
              value: _paidOn,
              onChanged: (v) => setState(() => _paidOn = v),
            ),
          ),
          FormSection(
            label: 'Paid from',
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final m in const [
                  PaymentMethod.bankTransfer,
                  PaymentMethod.upi,
                  PaymentMethod.wallet,
                  PaymentMethod.cash,
                ])
                  GlassChip(
                    label: m.label,
                    selected: _method == m,
                    onTap: () => setState(() => _method = m),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Saved as a card bill payment: it settles what you owe and is not '
            'counted as new spending.',
            style: context.text.bodySmall,
          ),
        ],
      ),
      actions: _saveButton('Record payment', _submit),
    );
  }
}

// ---------------------------------------------------------------------------
// EMI
// ---------------------------------------------------------------------------

/// Add or edit an EMI plan billed to [card]. Pops with an [EmiPlan].
class EmiFormSheet extends StatefulWidget {
  const EmiFormSheet({
    super.key,
    required this.card,
    required this.now,
    this.initial,
  });

  final CreditCard card;
  final DateTime now;
  final EmiPlan? initial;

  @override
  State<EmiFormSheet> createState() => _EmiFormSheetState();
}

class _EmiFormSheetState extends State<EmiFormSheet> {
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _principal = TextEditingController(
    text: widget.initial == null
        ? ''
        : moneyInputText(widget.initial!.principal),
  );
  late final _instalment = TextEditingController(
    text: widget.initial == null
        ? ''
        : moneyInputText(widget.initial!.instalment),
  );
  late final _tenure = TextEditingController(
    text: widget.initial?.tenureMonths.toString() ?? '',
  );
  late final _rate = TextEditingController(
    text: widget.initial?.annualInterestRate?.toString() ?? '',
  );
  late final _fee = TextEditingController(
    text: widget.initial?.processingFee == null
        ? ''
        : moneyInputText(widget.initial!.processingFee!),
  );
  late DateTime _firstDue =
      widget.initial?.firstDueDate ??
      DateTime(widget.now.year, widget.now.month + 1, widget.card.dueDay);
  final _errors = <String, String?>{};

  @override
  void dispose() {
    for (final c in [_title, _principal, _instalment, _tenure, _rate, _fee]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final principal = parseMoney(_principal.text, currencyCode: _currency);
    final instalment = parseMoney(_instalment.text, currencyCode: _currency);
    final tenure = int.tryParse(_tenure.text.trim());
    final rate = _rate.text.trim().isEmpty
        ? null
        : double.tryParse(_rate.text.trim());
    final fee = _fee.text.trim().isEmpty
        ? null
        : parseMoney(_fee.text, currencyCode: _currency);
    setState(() {
      _errors
        ..['title'] = _title.text.trim().isEmpty ? 'What was bought?' : null
        ..['principal'] = principal == null || !principal.isPositive
            ? 'Enter the purchase amount'
            : null
        ..['instalment'] = instalment == null || !instalment.isPositive
            ? 'Enter the monthly instalment'
            : null
        ..['tenure'] = tenure == null || tenure < 1 || tenure > 120
            ? 'Months, between 1 and 120'
            : null
        ..['rate'] =
            _rate.text.trim().isNotEmpty &&
                (rate == null || rate < 0 || rate > 100)
            ? 'Enter a rate like 13.5'
            : null
        ..['fee'] = _fee.text.trim().isNotEmpty && fee == null
            ? 'Enter a valid amount'
            : null;
    });
    if (_errors.values.any((e) => e != null)) return;
    Navigator.of(context).pop(
      EmiPlan(
        id: widget.initial?.id ?? '',
        title: _title.text.trim(),
        cardId: widget.card.id,
        principal: principal!,
        instalment: instalment!,
        tenureMonths: tenure!,
        firstDueDate: _firstDue,
        annualInterestRate: rate,
        processingFee: fee,
        closedOn: widget.initial?.closedOn,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: widget.initial == null ? 'Add EMI' : 'Edit EMI',
      subtitle: '${widget.card.name} · from the conversion details',
      icon: Icons.calendar_month_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _title,
            label: 'What is it for?',
            hint: 'e.g. Laptop',
            prefixIcon: Icons.shopping_bag_outlined,
            errorText: _errors['title'],
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          AmountField(
            controller: _principal,
            currencySymbol: _symbol,
            label: 'Purchase amount',
            large: false,
            errorText: _errors['principal'],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: AmountField(
                  controller: _instalment,
                  currencySymbol: _symbol,
                  label: 'Monthly EMI',
                  large: false,
                  errorText: _errors['instalment'],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: AppTextField(
                  controller: _tenure,
                  label: 'Months',
                  keyboardType: TextInputType.number,
                  errorText: _errors['tenure'],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
          FormSection(
            label: 'Schedule',
            child: DateField(
              label: 'First instalment due',
              value: _firstDue,
              onChanged: (v) => setState(() => _firstDue = v),
            ),
          ),
          FormSection(
            label: 'Cost (optional)',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _rate,
                    label: 'Interest % a year',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    errorText: _errors['rate'],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AmountField(
                    controller: _fee,
                    currencySymbol: _symbol,
                    label: 'Processing fee',
                    large: false,
                    errorText: _errors['fee'],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: _saveButton(
        widget.initial == null ? 'Add EMI' : 'Save EMI',
        _submit,
      ),
    );
  }
}

/// Opens a sheet from this file.
Future<T?> showFormSheet<T>(BuildContext context, Widget sheet) =>
    AppBottomSheet.show<T>(context, builder: (_) => sheet);
