import 'package:flutter/material.dart';

// Phase 6: language switch (ar/en + RTL), default currency, display name, logout
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(child: Text('Settings — Phase 6')),
    );
  }
}
