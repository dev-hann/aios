import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/presentation/widgets/status_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapWithMaterial(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('StatusBar', () {
    testWidgets('showsIdleState', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(const StatusBar(serviceState: ServiceState.idle)),
      );

      expect(find.text('Idle'), findsOneWidget);
    });

    testWidgets('showsReadyState', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const StatusBar(
            serviceState: ServiceState.ready,
            contextUsage: '128/2048 tokens',
          ),
        ),
      );

      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('128/2048 tokens'), findsOneWidget);
    });

    testWidgets('showsGeneratingState', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const StatusBar(serviceState: ServiceState.generating),
        ),
      );

      expect(find.text('Generating...'), findsOneWidget);
    });
  });
}
