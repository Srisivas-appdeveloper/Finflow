import 'package:flutter/material.dart';

/// The five primary navigation destinations, in display order.
enum AppTab {
  home('Home', Icons.home_outlined, Icons.home_rounded),
  activity('Activity', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
  cards('Cards', Icons.credit_card_outlined, Icons.credit_card_rounded),
  insights('Insights', Icons.insights_outlined, Icons.insights_rounded),
  profile('Profile', Icons.person_outline_rounded, Icons.person_rounded);

  const AppTab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
