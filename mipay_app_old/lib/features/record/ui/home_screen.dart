import 'package:flutter/material.dart';

// Phase 5: implement mic button, recording state machine, confirm sheet
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MiPay'), actions: [
        IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {}),
      ]),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.large(
              onPressed: () {},
              tooltip: 'Record voice note',
              child: const Icon(Icons.mic),
            ),
            const SizedBox(height: 16),
            const Text('Tap to record'),
          ],
        ),
      ),
    );
  }
}
