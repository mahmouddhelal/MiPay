import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mipay_app/l10n/app_localizations.dart';

import '../models/summary.dart';
import '../providers/summary_provider.dart';

// Fixed palette — one colour per category slot (cycles if > 12 categories)
const _kPalette = [
  Color(0xFF6366F1), // indigo
  Color(0xFFF59E0B), // amber
  Color(0xFF10B981), // emerald
  Color(0xFFEF4444), // red
  Color(0xFF3B82F6), // blue
  Color(0xFFF97316), // orange
  Color(0xFF8B5CF6), // violet
  Color(0xFF14B8A6), // teal
  Color(0xFFEC4899), // pink
  Color(0xFF84CC16), // lime
  Color(0xFF06B6D4), // cyan
  Color(0xFFA855F7), // purple
];

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
              error: (e, _) => Center(child: Text(e.toString())),
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
    final cur = summary.currency;

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
              color: Colors.green,
            ),
            const SizedBox(width: 8),
            _StatCard(
              label: l10n.totalExpenses,
              amount: summary.totalExpense,
              currency: cur,
              color: Colors.red,
            ),
            const SizedBox(width: 8),
            _StatCard(
              label: l10n.balance,
              amount: summary.balance,
              currency: cur,
              color: summary.balance >= 0 ? Colors.blue : Colors.orange,
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Donut chart
        if (summary.byCategory.isNotEmpty) ...[
          _DonutChart(categories: summary.byCategory, currency: cur),
          const SizedBox(height: 16),
          _CategoryList(categories: summary.byCategory, currency: cur),
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
    required this.color,
  });

  final String label;
  final double amount;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compact();
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
                '${fmt.format(amount)} $currency',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.bold),
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
  const _DonutChart({required this.categories, required this.currency});

  final List<CategorySummary> categories;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final sections = [
      for (var i = 0; i < categories.length; i++)
        PieChartSectionData(
          value: categories[i].total,
          color: _kPalette[i % _kPalette.length],
          radius: 56,
          showTitle: false,
        ),
    ];

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: sections,
          centerSpaceRadius: 52,
          sectionsSpace: 2,
          pieTouchData: PieTouchData(enabled: false),
        ),
      ),
    );
  }
}

// ── Category breakdown list ──────────────────────────────────────────────────

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.categories, required this.currency});

  final List<CategorySummary> categories;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final total = categories.fold<double>(0, (s, c) => s + c.total);
    final fmt = NumberFormat('#,##0.##');

    return Column(
      children: [
        for (var i = 0; i < categories.length; i++)
          _CategoryRow(
            cat: categories[i],
            color: _kPalette[i % _kPalette.length],
            pct: total > 0 ? categories[i].total / total : 0,
            currency: currency,
            fmt: fmt,
          ),
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
    required this.fmt,
  });

  final CategorySummary cat;
  final Color color;
  final double pct;
  final String currency;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              cat.category,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            '${(pct * 100).toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 12),
          Text(
            '${fmt.format(cat.total)} $currency',
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
