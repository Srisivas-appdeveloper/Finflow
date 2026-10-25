import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../shared/widgets/state_views.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: EmptyStateView(
          icon: Icons.explore_off_rounded,
          title: 'Page not found',
          message: 'The page you were looking for doesn\'t exist.',
          actionLabel: 'Go home',
          onAction: () => Get.until((route) => route.isFirst),
        ),
      ),
    );
  }
}
