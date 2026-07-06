import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mipay_app/l10n/app_localizations.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/category_avatar.dart';
import '../../../core/widgets/circle_action_button.dart';
import '../../../core/widgets/gradient_balance_card.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/segmented_pills.dart';
import '../../auth/providers/auth_controller.dart';
import '../../transactions/models/category.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../../transactions/ui/transaction_form.dart';
import '../models/summary.dart';
import '../providers/summary_provider.dart';

String _monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

/// Which half of the category breakdown is shown: expenses or income.
enum _ViewMode { expense, income }

final _viewModeProvider = StateProvider<_ViewMode>((ref) => _ViewMode.expense);
final _hideBalanceProvider = StateProvider<bool>((ref) => false);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(dashboardMonthProvider);
    final monthKey = _monthKey(selectedMonth);
    final summaryAsync = ref.watch(summaryProvider(monthKey));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: summaryAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => const SizedBox.shrink(),
                data: (summary) => _SummaryBody(
                  summary: summary,
                  selectedMonth: selectedMonth,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header: avatar initials + display name + settings ───────────────────────

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth is AuthAuthenticated ? auth.user : null;
    final name = user?.displayName ?? '';
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((s) => s[0]).join().toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              initials,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              name,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }
}

// ── Month stepper (pill) ─────────────────────────────────────────────────────

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
    final theme = Theme.of(context);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed: () => ref.read(dashboardMonthProvider.notifier).state =
                  DateTime(selectedMonth.year, selectedMonth.month - 1),
            ),
            Text(label, style: theme.textTheme.labelLarge),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: isCurrentMonth
                  ? null
                  : () => ref.read(dashboardMonthProvider.notifier).state =
                      DateTime(selectedMonth.year, selectedMonth.month + 1),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary body ─────────────────────────────────────────────────────────────

class _SummaryBody extends ConsumerWidget {
  const _SummaryBody({required this.summary, required this.selectedMonth});

  final Summary summary;
  final DateTime selectedMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final cur = summary.currency;
    final locale = Localizations.localeOf(context).toString();
    final hideBalance = ref.watch(_hideBalanceProvider);
    final viewMode = ref.watch(_viewModeProvider);

    // The backend now returns separate expense/income category breakdowns
    // (by_category / by_category_income) — pick the one the toggle asks for.
    // Filtering a single combined list by category "kind" doesn't work: a
    // kind="both" category (e.g. "other") could hold an expense-only total,
    // which would then incorrectly leak into the income view too.
    final filtered = viewMode == _ViewMode.expense
        ? summary.byCategory
        : summary.byCategoryIncome;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl,
      ),
      children: [
        GradientBalanceCard(
          title: l10n.balance,
          amount: summary.balance,
          currency: cur,
          locale: locale,
          incomeAmount: summary.totalIncome,
          expenseAmount: summary.totalExpense,
          hideBalance: hideBalance,
          onToggleHide: () =>
              ref.read(_hideBalanceProvider.notifier).state = !hideBalance,
          actions: [
            CircleActionButton(
              icon: Icons.add,
              label: l10n.addAction,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TransactionFormScreen()),
              ),
            ),
            CircleActionButton(
              icon: Icons.mic_none,
              label: l10n.recordAction,
              onTap: () => context.go('/home'),
            ),
            CircleActionButton(
              icon: Icons.arrow_downward,
              label: l10n.income,
              selected: viewMode == _ViewMode.income,
              onTap: () =>
                  ref.read(_viewModeProvider.notifier).state = _ViewMode.income,
            ),
            CircleActionButton(
              icon: Icons.arrow_upward,
              label: l10n.expense,
              selected: viewMode == _ViewMode.expense,
              onTap: () =>
                  ref.read(_viewModeProvider.notifier).state = _ViewMode.expense,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _MonthStepper(selectedMonth: selectedMonth, ref: ref),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: l10n.dashboard,
          trailing: SegmentedPills<_ViewMode>(
            segments: [
              PillSegment(value: _ViewMode.expense, label: l10n.expense),
              PillSegment(value: _ViewMode.income, label: l10n.income),
            ],
            selected: {viewMode},
            onChanged: (s) =>
                ref.read(_viewModeProvider.notifier).state = s.first,
          ),
          child: filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: Text(
                      l10n.noTransactions,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              : Column(
                  children: [
                    _DonutChart(categories: filtered, currency: cur, locale: locale),
                    const SizedBox(height: AppSpacing.md),
                    _CategoryList(categories: filtered, currency: cur, locale: locale),
                  ],
                ),
        ),
      ],
    );
  }
}

// ── Donut chart ──────────────────────────────────────────────────────────────

class _DonutChart extends StatelessWidget {
  const _DonutChart({
    required this.categories,
    required this.currency,
    required this.locale,
  });

  final List<CategorySummary> categories;
  final String currency;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final sorted = [...categories]..sort((a, b) => b.total.compareTo(a.total));
    final total = categories.fold<double>(0, (s, c) => s + c.total);

    final sections = [
      for (final c in sorted)
        PieChartSectionData(
          value: c.total,
          color: AppColors.categoryColor(c.category),
          radius: 26,
          showTitle: false,
        ),
    ];

    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 66,
              sectionsSpace: 3,
              pieTouchData: PieTouchData(enabled: false),
            ),
          ),
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
                '‎${formatCurrency(total, currency, locale)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
    final categoriesData = ref.watch(categoriesProvider).valueOrNull ?? [];
    final appLocale = Localizations.localeOf(context);

    final sorted = [...categories]..sort((a, b) => b.total.compareTo(a.total));
    final total = categories.fold<double>(0, (s, c) => s + c.total);

    Category? findCat(String key) =>
        categoriesData.where((c) => c.key == key).firstOrNull;

    return Column(
      children: [
        for (var i = 0; i < sorted.length; i++) ...[
          _CategoryRow(
            cat: sorted[i],
            pct: total > 0 ? sorted[i].total / total : 0,
            currency: currency,
            locale: locale,
            categoryObj: findCat(sorted[i].category),
            appLocale: appLocale,
          ),
          if (i != sorted.length - 1) const Divider(height: 1),
        ],
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.cat,
    required this.pct,
    required this.currency,
    required this.locale,
    required this.categoryObj,
    required this.appLocale,
  });

  final CategorySummary cat;
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
          CategoryAvatar(categoryKey: cat.category, icon: icon, size: 28),
          const SizedBox(width: 10),
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
