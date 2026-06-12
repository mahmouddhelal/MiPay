// Basic smoke test for the MiPay app.
//
// Verifies the app boots and renders without throwing.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mipay_app/app.dart';

void main() {
  testWidgets('MiPayApp builds without error', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MiPayApp()));
    await tester.pump();

    expect(find.byType(MiPayApp), findsOneWidget);
  });
}
