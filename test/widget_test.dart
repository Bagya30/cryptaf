import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cryptaf/main.dart';

void main() {
  testWidgets('GoldShimmerText renders correctly', (WidgetTester tester) async {
    // A meaningful widget test for a custom Cryptaf UI component
    // that does not require Firebase initialization.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GoldShimmerText(
            text: 'Test Shimmer',
          ),
        ),
      ),
    );

    // Verify the text renders
    expect(find.text('Test Shimmer'), findsOneWidget);

    // Verify it uses ShaderMask (which creates the shimmer effect)
    expect(find.byType(ShaderMask), findsOneWidget);
  });
}
