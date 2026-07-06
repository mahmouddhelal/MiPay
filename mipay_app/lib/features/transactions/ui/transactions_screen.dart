import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mipay_app/l10n/app_localizations.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/category_avatar.dart';
import '../../../core/widgets/segmented_pills.dart';
import '../../../features/dashboard/providers/summary_provider.dart';
import '../data/transactions_repository.dart';
import '../models/transaction.dart';
import '../providers/transactions_provider.dart';
import 'transaction_form.dart';
import 'transaction_tile.dart';

/// Transactions optimistically hidden mid-delete: [_DismissibleTile] adds an
/// id here *synchronously* on swipe-dismiss, before the async delete call, so
/// the item is already gone from the rendered list on the very next frame.
/// Without this, Dismissible briefly asserts "A dismissed Dismissible widget
/// is still part of the tree" (visible as a red error flash) because the
/// underlying list still contained the item during the network round-trip.
final _pendingDeleteIdsProvider = StateProvider<Set<String>>((ref) => {});

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final filter = ref.watch(transactionFilterProvider);
    final txAsync = ref.watch(transactionsProvider(filter));
    final pendingDeletes = ref.watch(_pendingDeleteIdsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.transactions)),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.brandGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.brandGradientEnd.withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TransactionFormScreen()),
          ),
          tooltip: l10n.addTransaction,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          const _FilterBar(),
          const Divider(height: 1),
          Expanded(
            child: txAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const SizedBox.shrink(),
              data: (allTxs) {
                final txs = pendingDeletes.isEmpty
                    ? allTxs
                    : allTxs.where((t) => !pendingDeletes.contains(t.id)).toList();
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
              // Month stepper (pill)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 20),
                        onPressed: () => _shiftMonth(ref, monthDate, -1),
                      ),
                      Text(
                        formatMonth(monthDate, locale.toString()),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        onPressed: () => _shiftMonth(ref, monthDate, 1),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Type toggle
              SegmentedPills<String>(
                emptySelectionAllowed: true,
                segments: [
                  PillSegment(value: 'expense', label: l10n.expense),
                  PillSegment(value: 'income', label: l10n.income),
                ],
                selected: {if (filter.type != null) filter.type!},
                onChanged: (s) {
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
                  child: _CategoryChip(
                    label: l10n.allCategories,
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
                    child: _CategoryChip(
                      avatar: CategoryAvatar(categoryKey: c.key, icon: c.iconData, size: 20),
                      label: c.labelFor(locale),
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

/// A [FilterChip] with an explicit, theme-correct label color for both the
/// selected and unselected state. The default chip label color is ambiguous
/// against this app's inverted `primary` (near-black in light mode, near-
/// white in dark mode) and was rendering near-invisible in both themes.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    this.avatar,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final Widget? avatar;
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;

    return FilterChip(
      avatar: avatar,
      label: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
      selected: selected,
      onSelected: onSelected,
      checkmarkColor: colorScheme.onPrimary,
    );
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
        formatDate(day, locale.toString()).toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
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
        // Hide the item immediately (before the async delete below) so
        // Dismissible never finds it still present in the underlying list.
        ref.read(_pendingDeleteIdsProvider.notifier).update(
              (s) => {...s, transaction.id},
            );
        try {
          await ref.read(transactionsRepositoryProvider).delete(transaction.id);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.errorNetwork)),
            );
          }
        } finally {
          ref.invalidate(transactionsProvider);
          ref.invalidate(summaryProvider);
          // Wait for the refetch so the pending-hide is only lifted once the
          // real list (with or without the item, success or failure) has
          // actually loaded — otherwise briefly re-showing stale data would
          // flicker the item back in before the fresh fetch completes.
          try {
            final filter = ref.read(transactionFilterProvider);
            await ref.read(transactionsProvider(filter).future);
          } catch (_) {
            // ignore — pending id is cleared below regardless
          }
          ref.read(_pendingDeleteIdsProvider.notifier).update(
                (s) => {...s}..remove(transaction.id),
              );
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
