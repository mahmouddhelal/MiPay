import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mipay_app/l10n/app_localizations.dart';

import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/category_avatar.dart';
import '../models/transaction.dart';
import '../providers/transactions_provider.dart';

class TransactionTile extends ConsumerWidget {
  const TransactionTile({super.key, required this.transaction, this.onTap});

  final Transaction transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    final isExpense = transaction.isExpense;

    final categoryAsync = ref.watch(categoriesProvider);
    final category = categoryAsync.valueOrNull
        ?.where((c) => c.key == transaction.category)
        .firstOrNull;

    final sign = isExpense ? '-' : '+';
    final amountColor = isExpense
        ? context.semantics.expense
        : context.semantics.income;

    return ListTile(
      onTap: onTap,
      leading: CategoryAvatar(
        categoryKey: transaction.category,
        icon: category?.iconData ?? Icons.more_horiz,
        size: 40,
      ),
      title: Text(
        transaction.name ?? category?.labelFor(locale) ?? transaction.category,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          if (transaction.source == 'voice') ...[
            const Icon(Icons.mic, size: 14),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              category?.labelFor(locale) ?? transaction.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: Text(
        '‎$sign${formatCurrency(transaction.amount, transaction.currency, locale.toString())}',
        style: TextStyle(
          color: amountColor,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        semanticsLabel:
            '${isExpense ? l10n.expense : l10n.income} ${transaction.amount} ${transaction.currency}',
      ),
    );
  }
}
