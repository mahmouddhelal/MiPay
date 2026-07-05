import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mipay_app/l10n/app_localizations.dart';

import '../../../core/utils/formatters.dart';
import '../../../features/dashboard/providers/summary_provider.dart';
import '../data/transactions_repository.dart';
import '../models/transaction.dart';
import '../providers/transactions_provider.dart';
import 'transaction_form.dart';
import 'transaction_tile.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final filter = ref.watch(transactionFilterProvider);
    final txAsync = ref.watch(transactionsProvider(filter));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.transactions)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TransactionFormScreen()),
        ),
        tooltip: l10n.addTransaction,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          const _FilterBar(),
          const Divider(height: 1),
          Expanded(
            child: txAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const SizedBox.shrink(),
              data: (txs) {
                if (txs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.outlineVariant),
                        const SizedBox(height: 16),
                        Text(l10n.noTransactions,
                            style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const TransactionFormScreen()),
                          ),
                          icon: const Icon(Icons.add),
                          label: Text(l10n.addTransaction),
                        ),
                      ],
                    ),
                  );
                }
                final groups = groupByDay(txs);
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(transactionsProvider),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: groups.fold<int>(0, (n, g) => n + g.items.length + 1),
                    itemBuilder: (context, index) {
                      var i = index;
                      for (final g in groups) {
                        if (i == 0) return _DayHeader(day: g.day);
                        i--;
                        if (i < g.items.length) {
                          final tx = g.items[i];
                          return _DismissibleTile(transaction: tx);
                        }
                        i -= g.items.length;
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter bar: month selector + type toggle + category chips ───────────────

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final filter = ref.watch(transactionFilterProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];

    final monthDate = filter.month != null
        ? DateTime.parse('${filter.month}-01')
        : DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              // Month stepper
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shiftMonth(ref, monthDate, -1),
              ),
              Expanded(
                child: Text(
                  formatMonth(monthDate, locale.toString()),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _shiftMonth(ref, monthDate, 1),
              ),
              const SizedBox(width: 8),
              // Type toggle
              SegmentedButton<String>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                emptySelectionAllowed: true,
                segments: [
                  ButtonSegment(value: 'expense', label: Text(l10n.expense)),
                  ButtonSegment(value: 'income', label: Text(l10n.income)),
                ],
                selected: {if (filter.type != null) filter.type!},
                onSelectionChanged: (s) {
                  ref.read(transactionFilterProvider.notifier).state =
                      filter.copyWith(type: () => s.isEmpty ? null : s.first);
                },
              ),
            ],
          ),
          // Category chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(l10n.allCategories),
                    selected: filter.category == null,
                    onSelected: (_) {
                      ref.read(transactionFilterProvider.notifier).state =
                          filter.copyWith(category: () => null);
                    },
                  ),
                ),
                for (final c in categories)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      avatar: Icon(c.iconData, size: 16),
                      label: Text(c.labelFor(locale)),
                      selected: filter.category == c.key,
                      onSelected: (sel) {
                        ref.read(transactionFilterProvider.notifier).state =
                            filter.copyWith(category: () => sel ? c.key : null);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _shiftMonth(WidgetRef ref, DateTime current, int delta) {
    final next = DateTime(current.year, current.month + delta, 1);
    final month = '${next.year}-${next.month.toString().padLeft(2, '0')}';
    final filter = ref.read(transactionFilterProvider);
    ref.read(transactionFilterProvider.notifier).state =
        filter.copyWith(month: () => month);
  }
}

// ── Day header ──────────────────────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 4),
      child: Text(
        formatDate(day, locale.toString()),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

// ── Swipe-to-delete wrapper ─────────────────────────────────────────────────

class _DismissibleTile extends ConsumerWidget {
  const _DismissibleTile({required this.transaction});
  final Transaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 24),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.delete),
          content: Text(l10n.confirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.delete),
            ),
          ],
        ),
      ),
      onDismissed: (_) async {
        try {
          await ref.read(transactionsRepositoryProvider).delete(transaction.id);
        } finally {
          ref.invalidate(transactionsProvider);
          ref.invalidate(summaryProvider);
        }
      },
      child: TransactionTile(
        transaction: transaction,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TransactionFormScreen(existing: transaction),
          ),
        ),
      ),
    );
  }
}
