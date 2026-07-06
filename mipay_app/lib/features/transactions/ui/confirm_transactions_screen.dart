import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mipay_app/l10n/app_localizations.dart';

import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/widgets/category_avatar.dart';
import '../../dashboard/providers/summary_provider.dart';
import '../models/category.dart';
import '../../record/models/voice_extraction.dart';
import '../data/transactions_repository.dart';
import '../models/transaction.dart';
import '../providers/transactions_provider.dart';

const _currencies = [
  'EGP', 'USD', 'EUR', 'SAR', 'AED', 'KWD', 'QAR',
  'BHD', 'OMR', 'JOD', 'IQD', 'MAD', 'TND', 'LBP',
];

/// Confirm screen for voice/text extraction (§7.2 screen 5). One utterance can
/// yield several transactions, so each is shown as its own editable card and the
/// whole set is saved together via POST /transactions/batch.
class ConfirmTransactionsScreen extends ConsumerStatefulWidget {
  const ConfirmTransactionsScreen({super.key, required this.result});

  final VoiceExtractionResult result;

  @override
  ConsumerState<ConfirmTransactionsScreen> createState() =>
      _ConfirmTransactionsScreenState();
}

/// Mutable editing state for a single card. Holds its own controllers so each
/// card edits independently; disposed when the card is removed or screen closes.
class _CardState {
  _CardState(ExtractedFields f)
      : type = f.transactionType ?? 'expense',
        currency = f.currency,
        categoryKey = f.category,
        date = f.date,
        needsReview = f.needsReview,
        amountCtrl = TextEditingController(
            text: f.amount != null ? f.amount!.toStringAsFixed(2) : ''),
        nameCtrl = TextEditingController(text: f.name ?? '');

  String type;
  String currency;
  String? categoryKey;
  DateTime date;
  bool needsReview;
  final TextEditingController amountCtrl;
  final TextEditingController nameCtrl;

  void dispose() {
    amountCtrl.dispose();
    nameCtrl.dispose();
  }
}

class _ConfirmTransactionsScreenState
    extends ConsumerState<ConfirmTransactionsScreen> {
  late List<_CardState> _cards;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cards = widget.result.extractions.map(_CardState.new).toList();
  }

  @override
  void dispose() {
    for (final c in _cards) {
      c.dispose();
    }
    super.dispose();
  }

  void _removeCard(int index) {
    setState(() {
      _cards.removeAt(index).dispose();
    });
  }

  Future<void> _saveAll() async {
    final l10n = AppLocalizations.of(context)!;
    // Validate every card before saving the batch.
    for (final c in _cards) {
      final amount = double.tryParse(c.amountCtrl.text.trim());
      if (amount == null || amount <= 0 || c.categoryKey == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.needsReview)),
        );
        return;
      }
    }

    setState(() => _saving = true);
    final drafts = _cards
        .map((c) => TransactionDraft(
              transactionType: c.type,
              amount: double.parse(c.amountCtrl.text.trim()),
              currency: c.currency,
              category: c.categoryKey!,
              name: c.nameCtrl.text.trim().isEmpty ? null : c.nameCtrl.text.trim(),
              date: c.date,
              source: 'voice',
              transcript: widget.result.transcript,
            ))
        .toList();

    try {
      await ref.read(transactionsRepositoryProvider).createMany(drafts);
      ref.invalidate(transactionsProvider);
      ref.invalidate(summaryProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final transcript = widget.result.transcript;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(l10n.confirmTransactionsTitle(_cards.length)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (transcript.isNotEmpty) ...[
                    _TranscriptQuote(transcript: transcript),
                    const SizedBox(height: 12),
                  ],
                  for (int i = 0; i < _cards.length; i++)
                    _TransactionCard(
                      key: ValueKey(_cards[i]),
                      index: i,
                      card: _cards[i],
                      canRemove: _cards.length > 1,
                      onRemove: () => _removeCard(i),
                      onChanged: () => setState(() {}),
                    ),
                ],
              ),
            ),
            // Save All bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_saving || _cards.isEmpty) ? null : _saveAll,
                  child: _saving
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(l10n.saveAll(_cards.length)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TranscriptQuote extends StatelessWidget {
  const _TranscriptQuote({required this.transcript});
  final String transcript;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_quote, size: 16),
              const SizedBox(width: 4),
              Text(l10n.transcript, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 4),
          Text('"$transcript"', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _TransactionCard extends ConsumerWidget {
  const _TransactionCard({
    super.key,
    required this.index,
    required this.card,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  final int index;
  final _CardState card;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final categoriesAsync = ref.watch(categoriesProvider);
    final currencyItems = _currencies.contains(card.currency)
        ? _currencies
        : [card.currency, ..._currencies];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: card.needsReview ? context.semantics.warningContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: index + needs-review tag + remove
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  child: Text('${index + 1}',
                      style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                if (card.needsReview)
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber,
                            size: 18, color: context.semantics.warning),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(l10n.needsReview,
                              style: TextStyle(
                                  fontSize: 12, color: context.semantics.warning)),
                        ),
                      ],
                    ),
                  )
                else
                  const Spacer(),
                if (canRemove)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: l10n.removeTransaction,
                    onPressed: onRemove,
                  ),
              ],
            ),
            const SizedBox(height: 4),

            // Type toggle
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                    value: 'expense',
                    label: Text(l10n.expense),
                    icon: const Icon(Icons.arrow_upward)),
                ButtonSegment(
                    value: 'income',
                    label: Text(l10n.income),
                    icon: const Icon(Icons.arrow_downward)),
              ],
              selected: {card.type},
              onSelectionChanged: (s) {
                card.type = s.first;
                onChanged();
              },
            ),
            const SizedBox(height: 12),

            // Amount + currency
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: card.amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.amount,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: card.currency,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.currency,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: currencyItems
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        card.currency = v;
                        onChanged();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Category dropdown (compact — chips would be too tall per card)
            categoriesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (cats) {
                final visible = cats
                    .where((c) =>
                        c.kind == 'both' ||
                        (card.type == 'expense'
                            ? c.kind == 'expense'
                            : c.kind == 'income'))
                    .toList();
                final selected = visible
                    .where((c) => c.key == card.categoryKey)
                    .firstOrNull;
                // A tap-to-open, scrollable bottom-sheet picker. Replaces the
                // stock DropdownButton, whose overlay menu overflowed and did
                // not scroll once the taxonomy grew past ~15 categories.
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showModalBottomSheet<String>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (sheetCtx) => _CategorySheet(
                        categories: visible,
                        selectedKey: card.categoryKey,
                        locale: locale,
                        title: l10n.category,
                      ),
                    );
                    if (picked != null) {
                      card.categoryKey = picked;
                      onChanged();
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.category,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: Row(
                      children: [
                        if (selected != null) ...[
                          CategoryAvatar(
                            categoryKey: selected.key,
                            icon: selected.iconData,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(selected.labelFor(locale))),
                        ] else
                          Expanded(
                            child: Text(
                              l10n.category,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Name
            TextField(
              controller: card.nameCtrl,
              decoration: InputDecoration(
                labelText: l10n.name,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // Date
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: card.date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked != null) {
                  card.date = picked;
                  onChanged();
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.date,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                child: Text(
                    MaterialLocalizations.of(context).formatMediumDate(card.date)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A scrollable bottom-sheet category picker. Handles any number of
/// categories (the taxonomy grew to 29), which a stock dropdown menu could
/// not display or scroll. Returns the chosen category key, or null on dismiss.
class _CategorySheet extends StatelessWidget {
  const _CategorySheet({
    required this.categories,
    required this.selectedKey,
    required this.locale,
    required this.title,
  });

  final List<Category> categories;
  final String? selectedKey;
  final Locale locale;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: categories.length,
                itemBuilder: (context, i) {
                  final c = categories[i];
                  final selected = c.key == selectedKey;
                  return ListTile(
                    leading: CategoryAvatar(
                      categoryKey: c.key,
                      icon: c.iconData,
                      size: 36,
                    ),
                    title: Text(c.labelFor(locale)),
                    trailing: selected
                        ? Icon(Icons.check, color: theme.colorScheme.primary)
                        : null,
                    selected: selected,
                    onTap: () => Navigator.of(context).pop(c.key),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
