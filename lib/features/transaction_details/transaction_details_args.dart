import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../domain/entities/transaction.dart';

/// Optional navigation payload for the details page. The route's `:id`
/// parameter is always the source of truth; [transaction] lets the page
/// render instantly without a loading state, and [heroTag] links the avatar
/// animation with the tile that was tapped.
class TransactionDetailsArgs {
  const TransactionDetailsArgs({this.transaction, this.heroTag});

  final Transaction? transaction;
  final Object? heroTag;

  static Future<void> open(Transaction transaction, {Object? heroTag}) async {
    await Get.toNamed<void>(
      AppRoutes.transaction(transaction.id),
      arguments: TransactionDetailsArgs(
        transaction: transaction,
        heroTag: heroTag,
      ),
    );
  }
}
