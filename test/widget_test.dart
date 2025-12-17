import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shizlist/main.dart';

void main() {
  testWidgets('App should build without errors', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const ShizListApp());

    // Verify the app starts (basic smoke test)
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
