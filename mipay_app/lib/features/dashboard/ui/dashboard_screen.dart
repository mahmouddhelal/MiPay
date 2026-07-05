import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mipay_app/l10n/app_localizations.dart';

import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../transactions/models/category.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../models/summary.dart';
import '../providers/summary_provider.dart';

String _monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selectedMonth = ref.watch(dashboardMonthProvider);
    final monthKey = _monthKey(selectedMonth);
    final summaryAsync = ref.watch(summaryProvider(monthKey));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dashboard)),
      body: Column(
        children: [
          _MonthStepper(selectedMonth: selectedMonth, ref: ref),
          Expanded(
            child: summaryAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const SizedBox.shrink(),
              data: (summary) => _SummaryBody(summary: summary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Month stepper ────────────────────────────────────────────────────────────

class _MonthStepper extends StatelessWidget {
  const _MonthStepper({required this.selectedMonth, required this.ref});

  final DateTime selectedMonth;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth =
        selectedMonth.year == now.year && selectedMonth.month == now.month;
    final label = DateFormat('MMMM yyyy').format(selectedMonth);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => ref.read(dashboardMonthProvider.notifier).state =
                DateTime(selectedMonth.year, selectedMonth.month - 1),
          ),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: isCurrentMonth
                ? null
                : () => ref.read(dashboardMonthProvider.notifier).state =
                    DateTime(selectedMonth.year, selectedMonth.month + 1),
          ),
        ],
      ),
    );
  }
}

// ── Summary body ─────────────────────────────────────────────────────────────

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({required this.summary});

  final Summary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final semantics = context.semantics;
    final cur = summary.currency;
    final locale = Localizations.localeOf(context).toString();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stat cards
        Row(
          children: [
            _StatCard(
              label: l10n.totalIncome,
              amount: summary.totalIncome,
              currency: cur,
              locale: locale,
              color: semantics.income,
            ),
            const SizedBox(width: 8),
            _StatCard(
              label: l10n.totalExpenses,
              amount: summary.totalExpense,
              currency: cur,
              locale: locale,
              color: semantics.expense,
            ),
            const SizedBox(width: 8),
            _StatCard(
              label: l10n.balance,
              amount: summary.balance,
              currency: cur,
              locale: locale,
              color: summary.balance >= 0 ? semantics.income : semantics.expense,
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (summary.byCategory.isNotEmpty) ...[
          _DonutChart(
            categories: summary.byCategory,
            currency: cur,
            locale: locale,
            balance: summary.balance,
          ),
          const SizedBox(height: 16),
          _CategoryList(categories: summary.byCategory, currency: cur, locale: locale),
        ] else
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                l10n.noTransactions,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Stat card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.amount,
    required this.currency,
    required this.locale,
    required this.color,
  });

  final String label;
  final double amount;
  final String currency;
  final String locale;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '‎${formatCurrency(amount, currency, locale)}',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Donut chart ──────────────────────────────────────────────────────────────

class _DonutChart extends StatelessWidget {
  const _DonutChart({
    required this.categories,
    required this.currency,
    required this.locale,
    required this.balance,
  });

  final List<CategorySummary> categories;
  final String currency;
  final String locale;
  final double balance;

  @override
  Widget build(BuildContext context) {
    final palette = context.semantics.chartPalette;
    // Top 7 + aggregate "Other"
    final sorted = [...categories]..sort((a, b) => b.total.compareTo(a.total));
    final top = sorted.take(7).toList();
    final rest = sorted.skip(7).toList();
    final otherTotal = rest.fold<double>(0, (s, c) => s + c.total);
    final display = [
      ...top,
      if (otherTotal > 0) CategorySummary(category: 'other', total: otherTotal, count: 0),
    ];

    final sections = [
      for (var i = 0; i < display.length; i++)
        PieChartSectionData(
          value: display[i].total,
          color: palette[i % palette.length],
          radius: 52,
          showTitle: false,
        ),
    ];

    final colorScheme = Theme.of(context).colorScheme;
    final balanceColor = balance >= 0
        ? context.semantics.income
        : context.semantics.expense;

    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 60,
              sectionsSpace: 2,
              pieTouchData: PieTouchData(enabled: false),
            ),
          ),
          // Net balance in donut center
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.balance,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                '‎${formatCurrency(balance, currency, locale)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: balanceColor,
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Category breakdown list ──────────────────────────────────────────────────

class _CategoryList extends ConsumerWidget {
  const _CategoryList({
    required this.categories,
    required this.currency,
    required this.locale,
  });

  final List<CategorySummary> categories;
  final String currency;
  final String locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.semantics.chartPalette;
    final categoriesData = ref.watch(categoriesProvider).valueOrNull ?? [];
    final l10n = AppLocalizations.of(context)!;
    final appLocale = Localizations.localeOf(context);

    final sorted = [...categories]..sort((a, b) => b.total.compareTo(a.total));
    final top = sorted.take(7).toList();
    final rest = sorted.skip(7).toList();
    final otherTotal = rest.fold<double>(0, (s, c) => s + c.total);
    final total = categories.fold<double>(0, (s, c) => s + c.total);
    final display = [
      ...top,
      if (otherTotal > 0) CategorySummary(category: 'other', total: otherTotal, count: 0),
    ];

    Category? findCat(String key) =>
        categoriesData.where((c) => c.key == key).firstOrNull;

    return Column(
      children: [
        for (var i = 0; i < display.length; i++) ...[
          _CategoryRow(
            cat: display[i],
            color: palette[i % palette.length],
            pct: total > 0 ? display[i].total / total : 0,
            currency: currency,
            locale: locale,
            categoryObj: findCat(display[i].category),
            appLocale: appLocale,
          ),
          const Divider(height: 1),
        ],
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.cat,
    required this.color,
    required this.pct,
    required this.currency,
    required this.locale,
    required this.categoryObj,
    required this.appLocale,
  });

  final CategorySummary cat;
  final Color color;
  final double pct;
  final String currency;
  final String locale;
  final Category? categoryObj;
  final Locale appLocale;

  @override
  Widget build(BuildContext context) {
    final label = categoryObj?.labelFor(appLocale) ?? cat.category;
    final icon = categoryObj?.iconData ?? Icons.more_horiz;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            '${(pct * 100).toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 12),
          Text(
            '‎${formatCurrency(cat.total, currency, locale)}',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
