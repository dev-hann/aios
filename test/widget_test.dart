import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aios/main.dart';

void main() {
  group('AIOS App', () {
    testWidgets('renders app bar with AIOS title', (tester) async {
      await tester.pumpWidget(const AIOSApp());
      expect(find.text('AIOS'), findsOneWidget);
    });

    testWidgets('shows status indicator Idle when no model', (tester) async {
      await tester.pumpWidget(const AIOSApp());
      await tester.pumpAndSettle();
      expect(find.text('Idle'), findsOneWidget);
    });

    testWidgets('shows banner to load model when no model loaded', (tester) async {
      await tester.pumpWidget(const AIOSApp());
      await tester.pumpAndSettle();
      expect(find.textContaining('GGUF'), findsOneWidget);
    });

    testWidgets('has folder_open button in app bar', (tester) async {
      await tester.pumpWidget(const AIOSApp());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.folder_open), findsOneWidget);
    });

    testWidgets('has refresh button in app bar', (tester) async {
      await tester.pumpWidget(const AIOSApp());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('has send button', (tester) async {
      await tester.pumpWidget(const AIOSApp());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('input field exists', (tester) async {
      await tester.pumpWidget(const AIOSApp());
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('tapping folder icon opens model picker sheet', (tester) async {
      await tester.pumpWidget(const AIOSApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.folder_open));
      await tester.pumpAndSettle();
      expect(find.text('Available Models'), findsOneWidget);
      expect(find.text('No GGUF files found'), findsOneWidget);
    });
  });
}
