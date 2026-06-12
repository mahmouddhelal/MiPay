import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mipay_app/l10n/app_localizations.dart';

import '../../transactions/models/transaction.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../../transactions/ui/transaction_form.dart';
import '../../transactions/ui/transaction_tile.dart';
import '../models/voice_extraction.dart';
import '../providers/recording_controller.dart';
import 'mic_button.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _textCtrl = TextEditingController();

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  String get _locale => Localizations.localeOf(context).languageCode;

  void _onMicTap() {
    final state = ref.read(recordingControllerProvider);
    final controller = ref.read(recordingControllerProvider.notifier);
    if (state is RecordingActive) {
      controller.stopAndProcess(locale: _locale);
    } else {
      controller.startRecording();
    }
  }

  Future<void> _openConfirmSheet(VoiceExtractionResult result) async {
    final controller = ref.read(recordingControllerProvider.notifier);
    // failed → straight to the empty manual form (FR-07)
    final form = result.failed
        ? const TransactionFormScreen()
        : TransactionFormScreen(voiceResult: result);

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => form, fullscreenDialog: true),
    );
    controller.reset();
    if (saved == true && mounted) {
      _textCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.save)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(recordingControllerProvider);

    ref.listen<RecordingState>(recordingControllerProvider, (previous, next) {
      if (next is RecordingResult) {
        _openConfirmSheet(next.result);
      } else if (next is RecordingError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message), backgroundColor: Colors.red),
        );
        ref.read(recordingControllerProvider.notifier).reset();
      }
    });

    final isRecording = state is RecordingActive;
    final isProcessing = state is RecordingProcessing;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            MicButton(
              isRecording: isRecording,
              isProcessing: isProcessing,
              onTap: _onMicTap,
            ),
            const SizedBox(height: 12),
            _StatusLine(state: state),
            const SizedBox(height: 16),
            // Mode B (FEATURES.md): type instead of talking
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _textCtrl,
                enabled: !isRecording && !isProcessing,
                textInputAction: TextInputAction.send,
                onSubmitted: (text) => ref
                    .read(recordingControllerProvider.notifier)
                    .submitText(text, locale: _locale),
                decoration: InputDecoration(
                  hintText: l10n.orTypeInstead,
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: (isRecording || isProcessing)
                        ? null
                        : () => ref
                            .read(recordingControllerProvider.notifier)
                            .submitText(_textCtrl.text, locale: _locale),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Recent transactions
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(l10n.recentTransactions,
                    style: Theme.of(context).textTheme.titleSmall),
              ),
            ),
            const Expanded(child: _RecentList()),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state});
  final RecordingState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final text = switch (state) {
      RecordingActive(:final elapsedSeconds) =>
        '${l10n.tapToStop} · 0:${elapsedSeconds.toString().padLeft(2, '0')} / 0:$kMaxRecordSeconds',
      RecordingProcessing() => '${l10n.transcribing} ${l10n.analyzing}',
      _ => l10n.tapToRecord,
    };
    return Text(text, style: Theme.of(context).textTheme.bodyMedium);
  }
}

class _RecentList extends ConsumerWidget {
  const _RecentList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final filter = TransactionFilter.forMonth(DateTime.now());
    final txAsync = ref.watch(transactionsProvider(filter));

    return txAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (txs) {
        if (txs.isEmpty) {
          return Center(child: Text(l10n.noTransactions));
        }
        final recent = txs.take(5).toList();
        return ListView.builder(
          itemCount: recent.length,
          itemBuilder: (context, i) => TransactionTile(transaction: recent[i]),
        );
      },
    );
  }
}
