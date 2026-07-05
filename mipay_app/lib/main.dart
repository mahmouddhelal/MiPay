import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers/theme_mode_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persisted theme before first frame — no flash of wrong theme.
  final container = ProviderContainer();
  await container.read(themeModeProvider.notifier).load();

  runApp(UncontrolledProviderScope(
    container: container,
    child: const MiPayApp(),
  ));
}
