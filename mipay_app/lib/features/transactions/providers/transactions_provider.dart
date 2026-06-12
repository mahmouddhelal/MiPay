import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/transactions_repository.dart';
import '../models/category.dart';
import '../models/transaction.dart';

/// Category list — fetched once per session, cached.
final categoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(transactionsRepositoryProvider).categories();
});

/// Currently active list filter (month/category/type), driven by the filter bar.
final transactionFilterProvider = StateProvider<TransactionFilter>((ref) {
  final now = DateTime.now();
  final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  return TransactionFilter(month: month);
});

/// Transaction list for a given filter. Invalidate after any create/edit/delete:
///   ref.invalidate(transactionsProvider);
final transactionsProvider =
    FutureProvider.family<List<Transaction>, TransactionFilter>((ref, filter) {
  return ref.watch(transactionsRepositoryProvider).list(filter);
});

/// Groups a transaction list by calendar day, newest day first.
/// Items within a day keep their server order (created_at desc).
List<({DateTime day, List<Transaction> items})> groupByDay(List<Transaction> txs) {
  final map = <DateTime, List<Transaction>>{};
  for (final t in txs) {
    final day = DateTime(t.date.year, t.date.month, t.date.day);
    map.putIfAbsent(day, () => []).add(t);
  }
  final days = map.keys.toList()..sort((a, b) => b.compareTo(a));
  return [for (final d in days) (day: d, items: map[d]!)];
}
