import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/summary_repository.dart';
import '../models/summary.dart';

/// The month currently shown on the dashboard. Persists across rebuilds.
final dashboardMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Fetches the summary for a given 'YYYY-MM' string.
final summaryProvider = FutureProvider.family<Summary, String>((ref, month) {
  return ref.watch(summaryRepositoryProvider).getSummary(month);
});
