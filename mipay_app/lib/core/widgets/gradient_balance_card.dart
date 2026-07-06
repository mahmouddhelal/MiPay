import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/formatters.dart';

/// The dashboard hero: a gradient-filled card showing a headline amount
/// (with an optional hide/reveal toggle), optional income/expense
/// sub-values, and a row of quick-action buttons underneath.
class GradientBalanceCard extends StatelessWidget {
  const GradientBalanceCard({
    super.key,
    required this.title,
    required this.amount,
    required this.currency,
    required this.locale,
    this.incomeAmount,
    this.expenseAmount,
    required this.hideBalance,
    required this.onToggleHide,
    required this.actions,
  });

  final String title;
  final double amount;
  final String currency;
  final String locale;
  final double? incomeAmount;
  final double? expenseAmount;
  final bool hideBalance;
  final VoidCallback onToggleHide;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final amountText =
        hideBalance ? '••••••' : formatCurrency(amount, currency, locale);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: onToggleHide,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    hideBalance ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '‎$amountText',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (incomeAmount != null && expenseAmount != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _SubValue(
                  icon: Icons.arrow_downward,
                  amount: incomeAmount!,
                  currency: currency,
                  locale: locale,
                  hidden: hideBalance,
                ),
                const SizedBox(width: AppSpacing.lg),
                _SubValue(
                  icon: Icons.arrow_upward,
                  amount: expenseAmount!,
                  currency: currency,
                  locale: locale,
                  hidden: hideBalance,
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: actions,
          ),
        ],
      ),
    );
  }
}

class _SubValue extends StatelessWidget {
  const _SubValue({
    required this.icon,
    required this.amount,
    required this.currency,
    required this.locale,
    required this.hidden,
  });

  final IconData icon;
  final double amount;
  final String currency;
  final String locale;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(width: 4),
        Text(
          hidden ? '••••' : '‎${formatCurrency(amount, currency, locale)}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
