import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mipay_app/l10n/app_localizations.dart';

import '../../record/models/voice_extraction.dart';
import '../data/transactions_repository.dart';
import '../models/transaction.dart';
import '../providers/transactions_provider.dart';

const _currencies = [
  'SAR', 'USD', 'EUR', 'EGP', 'AED', 'KWD', 'QAR',
  'BHD', 'OMR', 'JOD', 'IQD', 'MAD', 'TND', 'LBP',
];

/// Manual entry + edit form (FR-08/FR-09), and — when [voiceResult] is given —
/// the confirm sheet for voice/text extraction (§7.2 screen 5).
class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key, this.existing, this.voiceResult});

  /// When non-null the form edits this transaction; otherwise it creates one.
  final Transaction? existing;

  /// When non-null the form is the extraction confirm sheet: fields are
  /// prefilled, the transcript is quoted on top, and the save carries
  /// source='voice' + the transcript.
  final VoiceExtractionResult? voiceResult;

  @override
  ConsumerState<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _noteCtrl;

  late String _type;
  late String _currency;
  String? _categoryKey;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final v = widget.voiceResult?.extraction;
    _type = e?.transactionType ?? v?.transactionType ?? 'expense';
    _currency = e?.currency ?? v?.currency ?? 'SAR';
    _categoryKey = e?.category ?? v?.category;
    _date = e?.date ?? v?.date ?? DateTime.now();
    final amount = e?.amount ?? v?.amount;
    _amountCtrl =
        TextEditingController(text: amount != null ? amount.toStringAsFixed(2) : '');
    _nameCtrl = TextEditingController(text: e?.name ?? v?.name ?? '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_categoryKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorRequired)),
      );
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(transactionsRepositoryProvider);
    final voice = widget.voiceResult;
    final draft = TransactionDraft(
      transactionType: _type,
      amount: double.parse(_amountCtrl.text.trim()),
      currency: _currency,
      category: _categoryKey!,
      name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      date: _date,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      source: voice != null ? 'voice' : 'manual',
      transcript: voice?.transcript,
    );

    try {
      if (widget.existing != null) {
        await repo.update(widget.existing!.id, draft);
      } else {
        await repo.create(draft);
      }
      ref.invalidate(transactionsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final categoriesAsync = ref.watch(categoriesProvider);
    final isEdit = widget.existing != null;
    final voice = widget.voiceResult;
    // Extraction may return a currency outside our short picker list
    final currencyItems =
        _currencies.contains(_currency) ? _currencies : [_currency, ..._currencies];

    return Scaffold(
      appBar: AppBar(
        title: Text(voice != null
            ? l10n.confirmTransaction
            : isEdit
                ? l10n.edit
                : l10n.addTransaction),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Confirm-sheet extras: quoted transcript + review banner
              if (voice != null && voice.transcript.isNotEmpty) ...[
                Container(
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
                          Text(l10n.transcript,
                              style: Theme.of(context).textTheme.labelSmall),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('"${voice.transcript}"',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (voice != null && voice.needsReview) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(l10n.needsReview,
                            style: TextStyle(color: Colors.amber.shade900)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Type toggle
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'expense',
                    label: Text(l10n.expense),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  ButtonSegment(
                    value: 'income',
                    label: Text(l10n.income),
                    icon: const Icon(Icons.arrow_downward),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 16),

              // Amount + currency on one row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.amount,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final parsed = double.tryParse(v?.trim() ?? '');
                        if (parsed == null || parsed <= 0) return l10n.errorRequired;
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: InputDecoration(
                        labelText: l10n.currency,
                        border: const OutlineInputBorder(),
                      ),
                      items: currencyItems
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setState(() => _currency = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category grid
              Text(l10n.category, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              categoriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
                data: (cats) {
                  final visible = cats
                      .where((c) =>
                          c.kind == 'both' ||
                          (_type == 'expense' ? c.kind == 'expense' : c.kind == 'income'))
                      .toList();
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in visible)
                        ChoiceChip(
                          avatar: Icon(c.iconData, size: 18),
                          label: Text(c.labelFor(locale)),
                          selected: _categoryKey == c.key,
                          onSelected: (_) => setState(() => _categoryKey = c.key),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: l10n.name,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Date picker
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.date,
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Text(MaterialLocalizations.of(context).formatMediumDate(_date)),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.note,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.save),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
