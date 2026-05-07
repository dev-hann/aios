import 'package:aios/core/theme/app_colors.dart';
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
    testWidgets('render_idleState_showsIdle', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(const StatusBar(serviceState: ServiceState.idle)),
      );

      expect(find.text('Idle'), findsOneWidget);
    });

    testWidgets('render_readyState_showsReady', (tester) async {
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

    testWidgets('render_generatingState_showsGenerating', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const StatusBar(serviceState: ServiceState.generating),
        ),
      );

      expect(find.text('Generating...'), findsOneWidget);
    });

    testWidgets('render_loadingModelState_showsLoadingModel', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const StatusBar(serviceState: ServiceState.loadingModel),
        ),
      );

      expect(find.text('Loading Model...'), findsOneWidget);
    });

    testWidgets('render_errorState_showsError', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const StatusBar(serviceState: ServiceState.error),
        ),
      );

      expect(find.text('Error'), findsOneWidget);
    });

    testWidgets('render_readyState_showsColoredDot', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const StatusBar(serviceState: ServiceState.ready),
        ),
      );

      final dot = tester.widget<Container>(find.byType(Container).first);
      final decoration = dot.decoration as BoxDecoration;
      expect(decoration.color, AppColors.ready);
      expect(decoration.shape, BoxShape.circle);
    });

    testWidgets('render_notReady_doesNotShowContextUsage', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const StatusBar(
            serviceState: ServiceState.generating,
            contextUsage: '128/2048 tokens',
          ),
        ),
      );

      expect(find.text('128/2048 tokens'), findsNothing);
    });

    testWidgets('render_nullContextUsage_doesNotShowContextUsage',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const StatusBar(serviceState: ServiceState.ready),
        ),
      );

      final textWidgets = find.byType(Text);
      expect(textWidgets, findsNWidgets(1));
    });

    testWidgets('render_readyWithUsage_showsContextUsage',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const StatusBar(
            serviceState: ServiceState.ready,
            contextUsage: '512/4096 tokens',
          ),
        ),
      );

      expect(find.text('512/4096 tokens'), findsOneWidget);
    });

    testWidgets('render_idleState_usesIdleColor', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const StatusBar(serviceState: ServiceState.idle),
        ),
      );

      final text = tester.widget<Text>(find.text('Idle'));
      expect(text.style?.color, AppColors.idle);
    });

    testWidgets('render_loadingModelState_usesLoadingColor', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const StatusBar(serviceState: ServiceState.loadingModel),
        ),
      );

      final text = tester.widget<Text>(find.text('Loading Model...'));
      expect(text.style?.color, AppColors.loadingModel);
    });

    testWidgets('render_errorState_usesErrorColor', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const StatusBar(serviceState: ServiceState.error),
        ),
      );

      final text = tester.widget<Text>(find.text('Error'));
      expect(text.style?.color, AppColors.error);
    });
  });
}
