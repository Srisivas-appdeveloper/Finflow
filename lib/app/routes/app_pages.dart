import 'package:get/get.dart';

import '../../core/motion/motion.dart';
import '../../core/motion/page_transitions.dart';
import '../../features/cards/card_details_binding.dart';
import '../../features/cards/card_details_page.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/profile/privacy_page.dart';
import '../../features/shell/not_found_page.dart';
import '../../features/split/split_bindings.dart';
import '../../features/split/split_expense_form_page.dart';
import '../../features/split/split_group_page.dart';
import '../../features/split/split_page.dart';
import '../../features/shell/shell_binding.dart';
import '../../features/shell/shell_page.dart';
import '../../features/transaction_details/transaction_details_binding.dart';
import '../../features/transaction_details/transaction_details_page.dart';
import '../../features/transaction_form/transaction_form_binding.dart';
import '../../features/transaction_form/transaction_form_page.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static final pages = <GetPage<dynamic>>[
    GetPage(
      name: AppRoutes.shell,
      page: () => const ShellPage(),
      binding: ShellBinding(),
      // The shell's transition also defines how it animates when another
      // page covers it (drift back and dim).
      customTransition: AppTransitions.slideOver,
      transitionDuration: AppMotion.page,
    ),
    GetPage(
      name: AppRoutes.onboarding,
      page: () => const OnboardingPage(),
      customTransition: AppTransitions.fadeThrough,
      transitionDuration: AppMotion.page,
    ),
    GetPage(
      name: AppRoutes.transactionDetails,
      page: () => const TransactionDetailsPage(),
      binding: TransactionDetailsBinding(),
      customTransition: AppTransitions.slideOver,
      transitionDuration: AppMotion.page,
    ),
    GetPage(
      name: AppRoutes.addTransaction,
      page: () => const TransactionFormPage(),
      binding: TransactionFormBinding(),
      customTransition: AppTransitions.slideUp,
      transitionDuration: AppMotion.page,
    ),
    GetPage(
      name: AppRoutes.editTransaction,
      page: () => const TransactionFormPage(),
      binding: TransactionFormBinding(),
      customTransition: AppTransitions.slideUp,
      transitionDuration: AppMotion.page,
    ),
    GetPage(
      name: AppRoutes.cardDetails,
      page: () => const CardDetailsPage(),
      binding: CardDetailsBinding(),
      customTransition: AppTransitions.slideOver,
      transitionDuration: AppMotion.page,
    ),
    GetPage(
      name: AppRoutes.split,
      page: () => const SplitPage(),
      binding: SplitBinding(),
      customTransition: AppTransitions.slideOver,
      transitionDuration: AppMotion.page,
    ),
    GetPage(
      name: AppRoutes.splitGroup,
      page: () => const SplitGroupPage(),
      binding: SplitGroupBinding(),
      customTransition: AppTransitions.slideOver,
      transitionDuration: AppMotion.page,
    ),
    GetPage(
      name: AppRoutes.splitExpense,
      page: () => const SplitExpenseFormPage(),
      binding: SplitExpenseFormBinding(),
      customTransition: AppTransitions.slideUp,
      transitionDuration: AppMotion.page,
    ),
    GetPage(
      name: AppRoutes.privacy,
      page: () => const PrivacyPage(),
      customTransition: AppTransitions.slideOver,
      transitionDuration: AppMotion.page,
    ),
  ];

  static final notFound = GetPage<dynamic>(
    name: '/not-found',
    page: () => const NotFoundPage(),
    customTransition: AppTransitions.fadeThrough,
    transitionDuration: AppMotion.page,
  );
}
