import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/motion/motion.dart';
import '../core/motion/page_transitions.dart';
import '../core/theme/app_theme.dart';
import '../domain/repositories/settings_repository.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';
import 'services/theme_controller.dart';

/// Root widget. Expects `AppBinding.dependencies()` to have run.
class FinFlowApp extends StatelessWidget {
  const FinFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Get.find<ThemeController>();
    final settings = Get.find<SettingsRepository>();
    return GetMaterialApp(
      title: 'FinFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: theme.themeMode,
      // First launch shows the onboarding clips.
      initialRoute: settings.onboardingComplete
          ? AppRoutes.shell
          : AppRoutes.onboarding,
      getPages: AppPages.pages,
      unknownRoute: AppPages.notFound,
      customTransition: AppTransitions.slideOver,
      transitionDuration: AppMotion.page,
      defaultTransition: Transition.native,
      builder: (context, child) => AnnotatedRegion(
        value: AppTheme.overlayFor(Theme.of(context).brightness),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
