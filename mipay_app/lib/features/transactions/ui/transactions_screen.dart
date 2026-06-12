import 'package:flutter/material.dart';

// Phase 2: implement transaction list, filters, swipe-to-delete
class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: const Center(child: Text('Transaction list — Phase 2')),
    );
  }
}
