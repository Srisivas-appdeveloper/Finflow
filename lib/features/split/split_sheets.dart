import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_environment.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money_input.dart';
import '../../domain/entities/money.dart';
import '../../domain/entities/split.dart';
import '../../domain/entities/transaction.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_inputs.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/selection.dart';
import 'widgets/split_widgets.dart';

String get _currency => Get.find<AppEnvironment>().currencyCode;
String get _symbol => Get.find<Formatters>().currencySymbol(_currency);

Widget _saveButton(String label, VoidCallback onPressed) => AppButton(
  label: label,
  icon: Icons.check_rounded,
  expand: true,
  onPressed: onPressed,
);

// ---------------------------------------------------------------------------
// Group
// ---------------------------------------------------------------------------

/// Create or edit a group. Pops with the edited [SplitGroup] (id empty for
/// new; new members have empty ids).
class GroupFormSheet extends StatefulWidget {
  const GroupFormSheet({
    super.key,
    required this.now,
    this.initial,
    this.lockedMemberIds = const {},
  });

  final DateTime now;
  final SplitGroup? initial;

  /// Members who appear in expenses or settlements and can't be removed.
  final Set<String> lockedMemberIds;

  @override
  State<GroupFormSheet> createState() => _GroupFormSheetState();
}

class _GroupFormSheetState extends State<GroupFormSheet> {
  late final _name = TextEditingController(text: widget.initial?.name);
  final _person = TextEditingController();
  final _personFocus = FocusNode();
  late final _members = [...?widget.initial?.members];

  /// Temporary ids for people added in this sheet; cleared on save so the
  /// repository assigns real ones.
  static const _newPrefix = '_new-';
  var _added = 0;
  String? _nameError;
  String? _peopleError;
  String? _lockedNote;

  @override
  void dispose() {
    _name.dispose();
    _person.dispose();
    _personFocus.dispose();
    super.dispose();
  }

  /// Adds the typed name. Returns false (with an error) if it can't.
  bool _addPerson() {
    final name = _person.text.trim();
    if (name.isEmpty) return true;
    final key = name.toLowerCase();
    String? error;
    if (key == 'you' || key == 'me') {
      error = 'You are already in the group';
    } else if (_members.any((m) => m.name.toLowerCase() == key)) {
      error = '$name is already in the group';
    }
    setState(() {
      _peopleError = error;
      if (error == null) {
        _members.add(SplitMember(id: '$_newPrefix${_added++}', name: name));
        _person.clear();
      }
    });
    _personFocus.requestFocus();
    return error == null;
  }

  void _remove(SplitMember m) {
    if (widget.lockedMemberIds.contains(m.id)) {
      setState(
        () => _lockedNote =
            '${m.name} is part of recorded expenses or payments, so they '
            'stay in the group.',
      );
      return;
    }
    setState(() {
      _members.remove(m);
      _lockedNote = null;
    });
  }

  void _submit() {
    if (!_addPerson()) return;
    setState(() {
      _nameError = _name.text.trim().isEmpty ? 'Give the group a name' : null;
      _peopleError = _members.isEmpty ? 'Add at least one other person' : null;
    });
    if (_nameError != null || _peopleError != null) return;
    final base = widget.initial;
    Navigator.of(context).pop(
      SplitGroup(
        id: base?.id ?? '',
        name: _name.text.trim(),
        members: [
          for (final m in _members)
            m.id.startsWith(_newPrefix) ? SplitMember(id: '', name: m.name) : m,
        ],
        createdAt: base?.createdAt ?? widget.now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = SplitGroup(
      id: '',
      name: '',
      members: _members,
      createdAt: widget.now,
    );
    return AppSheet(
      title: widget.initial == null ? 'New group' : 'Edit group',
      subtitle: 'A room, flat, trip or anyone you share costs with',
      icon: Icons.groups_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _name,
            label: 'Group name',
            hint: 'e.g. Room 204',
            prefixIcon: Icons.home_work_outlined,
            errorText: _nameError,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          FormSection(
            label: 'People',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PersonRow(
                  group: preview,
                  memberId: SplitMember.youId,
                  subtitle: 'Always in the group',
                ),
                for (final m in _members)
                  PersonRow(
                    group: preview,
                    memberId: m.id,
                    trailing: IconButton(
                      tooltip: 'Remove ${m.name}',
                      icon: Icon(
                        widget.lockedMemberIds.contains(m.id)
                            ? Icons.lock_outline_rounded
                            : Icons.remove_circle_outline_rounded,
                      ),
                      onPressed: () => _remove(m),
                    ),
                  ),
                if (_lockedNote != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(_lockedNote!, style: context.text.bodySmall),
                  ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _person,
                  focusNode: _personFocus,
                  label: 'Add a person',
                  hint: 'Name',
                  prefixIcon: Icons.person_add_alt_rounded,
                  errorText: _peopleError,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addPerson(),
                  onChanged: (_) {
                    if (_peopleError != null) {
                      setState(() => _peopleError = null);
                    }
                  },
                  suffix: IconButton(
                    tooltip: 'Add person',
                    icon: const Icon(Icons.add_rounded),
                    onPressed: _addPerson,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: _saveButton(
        widget.initial == null ? 'Create group' : 'Save group',
        _submit,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settlement
// ---------------------------------------------------------------------------

class SettlementDraft {
  const SettlementDraft({
    required this.fromId,
    required this.toId,
    required this.amount,
    required this.paidOn,
    required this.method,
  });

  final String fromId;
  final String toId;
  final Money amount;
  final DateTime paidOn;
  final PaymentMethod method;
}

/// Record money paid between two people in [group]. Pops with a
/// [SettlementDraft].
class SettleUpSheet extends StatefulWidget {
  const SettleUpSheet({
    super.key,
    required this.group,
    required this.now,
    this.fromId,
    this.toId,
    this.amount,
    this.method,
    this.editing = false,
  });

  final SplitGroup group;
  final DateTime now;
  final String? fromId;
  final String? toId;
  final Money? amount;
  final PaymentMethod? method;

  /// Editing a recorded settlement (changes the title and button).
  final bool editing;

  @override
  State<SettleUpSheet> createState() => _SettleUpSheetState();
}

class _SettleUpSheetState extends State<SettleUpSheet> {
  late String _from = widget.fromId ?? SplitMember.youId;
  late String _to =
      widget.toId ?? widget.group.everyoneIds.firstWhere((id) => id != _from);
  late final _amount = TextEditingController(
    text: widget.amount == null ? '' : moneyInputText(widget.amount!),
  );
  late DateTime _paidOn = widget.now;
  late PaymentMethod _method = widget.method ?? PaymentMethod.upi;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _setFrom(String id) {
    setState(() {
      _from = id;
      if (_to == id) {
        _to = widget.group.everyoneIds.firstWhere((other) => other != id);
      }
    });
  }

  void _submit() {
    final amount = parseMoney(_amount.text, currencyCode: _currency);
    if (amount == null || !amount.isPositive) {
      setState(() => _error = 'Enter an amount greater than zero');
      return;
    }
    Navigator.of(context).pop(
      SettlementDraft(
        fromId: _from,
        toId: _to,
        amount: amount,
        paidOn: _paidOn,
        method: _method,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final youInvolved = _from == SplitMember.youId || _to == SplitMember.youId;

    Widget people(String selected, ValueChanged<String> onTap, {String? not}) {
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final id in g.everyoneIds)
            if (id != not)
              GlassChip(
                label: g.nameOf(id),
                selected: selected == id,
                onTap: () => onTap(id),
              ),
        ],
      );
    }

    return AppSheet(
      title: widget.editing ? 'Edit payment' : 'Record a payment',
      subtitle: g.name,
      icon: Icons.handshake_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          AmountField(
            controller: _amount,
            currencySymbol: _symbol,
            errorText: _error,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          FormSection(label: 'Who paid', child: people(_from, _setFrom)),
          FormSection(
            label: 'Paid to',
            child: people(_to, (id) => setState(() => _to = id), not: _from),
          ),
          FormSection(
            label: 'Paid on',
            child: DateField(
              label: 'Payment date',
              value: _paidOn,
              onChanged: (v) => setState(() => _paidOn = v),
            ),
          ),
          if (youInvolved)
            FormSection(
              label: _from == SplitMember.youId ? 'Paid with' : 'Received via',
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final m in PaymentMethod.selectable)
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
            youInvolved
                ? 'Saved as a split settlement: it clears what is owed and is '
                      'not counted as spending or income.'
                : 'Only the group balances change; nothing is added to your '
                      'activity.',
            style: context.text.bodySmall,
          ),
        ],
      ),
      actions: _saveButton(
        widget.editing ? 'Save payment' : 'Record payment',
        _submit,
      ),
    );
  }
}

/// Opens a sheet from this file.
Future<T?> showSplitSheet<T>(BuildContext context, Widget sheet) =>
    AppBottomSheet.show<T>(context, builder: (_) => sheet);
