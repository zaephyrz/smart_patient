import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/app.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: SmartPatientApp(),
      ),
    );

    // Just pump once to render the initial frame
    await tester.pump();

    // Verify that the app is rendered
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('App shows some text', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SmartPatientApp(),
      ),
    );

    await tester.pump();

    // Just verify that there's some text on the screen
    expect(find.byType(Text), findsWidgets);
  });

  testWidgets('App has form fields for login', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SmartPatientApp(),
      ),
    );

    await tester.pump();

    // Check that we have form fields
    expect(find.byType(TextFormField), findsWidgets);
  });
}