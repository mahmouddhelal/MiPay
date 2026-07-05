import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_user_provider.dart';
import '../data/transactions_repository.dart';
import '../models/category.dart';
import '../models/transaction.dart';

/// Category list — reference data, not per-user, cached globally.
final categoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(transactionsRepositoryProvider).categories();
});

/// Active filter scoped to the current user. Resets automatically when the
/// user changes because it watches currentUserIdProvider.
final transactionFilterProvider =
    StateProvider.autoDispose<TransactionFilter>((ref) {
  ref.watch(currentUserIdProvider); // dispose when user changes
  final now = DateTime.now();
  final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  return TransactionFilter(month: month);
});

/// Transaction list for a given filter. autoDispose ensures user A's data is
/// never visible to user B. Invalidate after any create/edit/delete:
///   ref.invalidate(transactionsProvider);
final transactionsProvider =
    FutureProvider.autoDispose.family<List<Transaction>, TransactionFilter>(
        (ref, filter) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Future.value([]);
  return ref.watch(transactionsRepositoryProvider).list(filter);
});

/// Groups a transaction list by calendar day, newest day first.
/// Items within a day keep their server order (created_at desc).
List<({DateTime day, List<Transaction> items})> groupByDay(
    List<Transaction> txs) {
  final map = <DateTime, List<Transaction>>{};
  for (final t in txs) {
    final day = DateTime(t.date.year, t.date.month, t.date.day);
    map.putIfAbsent(day, () => []).add(t);
  }
  final days = map.keys.toList()..sort((a, b) => b.compareTo(a));
  return [for (final d in days) (day: d, items: map[d]!)];
}
