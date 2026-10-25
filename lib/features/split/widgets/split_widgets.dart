import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/money.dart';
import '../../../domain/entities/split.dart';

/// Round initials badge for a person. Colours follow the person's position
/// in the group, so everyone keeps the same colour on every screen.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.group,
    required this.memberId,
    this.size = 40,
  });

  final SplitGroup group;
  final String memberId;
  final double size;

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first.characters.first;
    final second = parts.length > 1 ? parts[1].characters.first : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    final you = memberId == SplitMember.youId;
    final index = group.members.indexWhere((m) => m.id == memberId);
    final color = you
        ? fin.accent
        : fin.categorical[(index < 0 ? 7 : index) % fin.categorical.length];
    final dark = Theme.of(context).brightness == Brightness.dark;
    final name = group.nameOf(memberId);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: you
            ? fin.accentGradient
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: dark ? 0.55 : 0.32),
                  color.withValues(alpha: dark ? 0.25 : 0.14),
                ],
              ),
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? 0.24 : 0.8),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        you ? 'You' : initials(name),
        semanticsLabel: name,
        style: context.text.labelMedium?.copyWith(
          fontSize: size * (you ? 0.27 : 0.34),
          fontWeight: FontWeight.w700,
          color: you || dark
              ? Colors.white
              : Color.lerp(color, Colors.black, 0.35),
        ),
      ),
    );
  }
}

/// Gradient orb with a people icon, for a group.
class GroupOrb extends StatelessWidget {
  const GroupOrb({super.key, this.size = 46});

  final double size;

  @override
  Widget build(BuildContext context) {
    final fin = context.fin;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: fin.accentGradient,
        border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: fin.accent.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(Icons.groups_rounded, color: Colors.white, size: size * 0.5),
    );
  }
}

/// How a balance reads, and its colour. [you] words it for the user.
({String text, Color color}) describeBalance(
  BuildContext context,
  Money balance, {
  required bool you,
}) {
  final fin = context.fin;
  final f = Get.find<Formatters>();
  if (balance.isZero) return (text: 'Settled up', color: fin.textMuted);
  if (balance.isPositive) {
    return (
      text: '${you ? 'You get' : 'Gets'} back ${f.money(balance)}',
      color: fin.income,
    );
  }
  return (
    text: '${you ? 'You owe' : 'Owes'} ${f.money(balance.abs())}',
    color: fin.pending,
  );
}

/// A person with their name and a trailing widget, used in lists.
class PersonRow extends StatelessWidget {
  const PersonRow({
    super.key,
    required this.group,
    required this.memberId,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final SplitGroup group;
  final String memberId;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.control,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            PersonAvatar(group: group, memberId: memberId),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.nameOf(memberId),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall,
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Right-aligned amount that shrinks rather than overflowing.
class TrailingAmount extends StatelessWidget {
  const TrailingAmount({
    super.key,
    required this.text,
    this.caption,
    this.color,
  });

  final String text;
  final String? caption;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.42,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              text,
              style: context.text.titleSmall?.tabular.copyWith(color: color),
            ),
          ),
          if (caption != null)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: Text(caption!, style: context.text.bodySmall),
            ),
        ],
      ),
    );
  }
}
