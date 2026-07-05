import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_user_provider.dart';
import '../data/summary_repository.dart';
import '../models/summary.dart';

/// The month currently shown on the dashboard. Resets when the user changes.
final dashboardMonthProvider = StateProvider.autoDispose<DateTime>((ref) {
  ref.watch(currentUserIdProvider); // dispose when user changes
  return DateTime.now();
});

/// Fetches the summary for a given 'YYYY-MM' string. autoDispose ensures
/// user A's totals are never shown to user B.
final summaryProvider =
    FutureProvider.autoDispose.family<Summary, String>((ref, month) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Future.value(Summary.empty());
  return ref.watch(summaryRepositoryProvider).getSummary(month);
});
