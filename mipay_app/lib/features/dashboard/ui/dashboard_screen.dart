import 'package:flutter/material.dart';

// Phase 6: implement summary cards, donut chart, per-category list
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: const Center(child: Text('Dashboard — Phase 6')),
    );
  }
}
