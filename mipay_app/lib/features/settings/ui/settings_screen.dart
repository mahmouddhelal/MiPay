import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mipay_app/l10n/app_localizations.dart';

import '../../../core/providers/theme_mode_provider.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/segmented_pills.dart';
import '../../auth/providers/auth_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _currencyCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authControllerProvider);
    final user = auth is AuthAuthenticated ? auth.user : null;
    _nameCtrl = TextEditingController(text: user?.displayName ?? '');
    _currencyCtrl = TextEditingController(text: user?.defaultCurrency ?? 'EGP');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    final currency = _currencyCtrl.text.trim().toUpperCase();
    if (name.isEmpty || currency.isEmpty) return;

    setState(() => _saving = true);
    try {
      await ref.read(authControllerProvider.notifier).updateProfile(
            displayName: name,
            defaultCurrency: currency,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.changesSaved),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _switchLocale(String locale) async {
    try {
      await ref.read(authControllerProvider.notifier).updateProfile(locale: locale);
    } catch (_) {
      // locale change is best-effort — UI already reflects new value via Provider
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(authControllerProvider);
    final user = auth is AuthAuthenticated ? auth.user : null;
    final currentLocale = user?.locale ?? 'en';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Profile section ───────────────────────────────────────────────
          SectionCard(
            title: l10n.profile,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(labelText: l10n.displayName),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _currencyCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.defaultCurrency,
                    hintText: 'EGP / USD / EUR',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 3,
                ),
                const SizedBox(height: 4),
                GradientButton(
                  onPressed: _saving ? null : _saveProfile,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l10n.save),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── Language section ──────────────────────────────────────────────
          SectionCard(
            title: l10n.language,
            child: SegmentedPills<String>(
              segments: [
                PillSegment(value: 'en', label: l10n.english),
                PillSegment(value: 'ar', label: l10n.arabic),
              ],
              selected: {currentLocale},
              onChanged: (sel) => _switchLocale(sel.first),
            ),
          ),
          const SizedBox(height: 16),
          // ── Appearance section ────────────────────────────────────────────
          SectionCard(
            title: 'Appearance',
            child: SegmentedButton<ThemeMode>(
              style: SegmentedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto),
                  label: Text('System'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode),
                  label: Text('Dark'),
                ),
              ],
              selected: {ref.watch(themeModeProvider)},
              onSelectionChanged: (sel) =>
                  ref.read(themeModeProvider.notifier).set(sel.first),
            ),
          ),
          const SizedBox(height: 16),
          // ── Account section ───────────────────────────────────────────────
          SectionCard(
            title: l10n.account,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(color: Theme.of(context).colorScheme.error),
              ),
              onPressed: () => ref.read(authControllerProvider.notifier).logout(),
              icon: const Icon(Icons.logout),
              label: Text(l10n.logout),
            ),
          ),
        ],
      ),
    );
  }
}
