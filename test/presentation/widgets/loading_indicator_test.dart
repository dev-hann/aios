import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/presentation/widgets/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapWithMaterial(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('LoadingIndicator', () {
    testWidgets('render_initializing_showsInitializing', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const LoadingIndicator(phase: LoadingPhase.initializing),
        ),
      );

      expect(find.text('AI 엔진 초기화 중...'), findsOneWidget);
    });

    testWidgets('render_loadingModel_showsLoadingModel', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const LoadingIndicator(phase: LoadingPhase.loadingModel),
        ),
      );

      expect(find.text('AI 모델 로딩 중...'), findsOneWidget);
    });

    testWidgets('render_preparing_showsPreparing', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const LoadingIndicator(phase: LoadingPhase.preparing),
        ),
      );

      expect(find.text('작업 공간 준비 중...'), findsOneWidget);
    });

    testWidgets('render_ready_showsReady', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(const LoadingIndicator(phase: LoadingPhase.ready)),
      );

      expect(find.text('준비 완료!'), findsOneWidget);
    });

    testWidgets('render_showsCircularProgressIndicator', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const LoadingIndicator(phase: LoadingPhase.loadingModel),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('render_ready_showsCheckIcon', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(const LoadingIndicator(phase: LoadingPhase.ready)),
      );

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('render_withMessage_showsCustomMessage', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const LoadingIndicator(
            phase: LoadingPhase.loadingModel,
            message: 'Loading custom model...',
          ),
        ),
      );

      expect(find.text('Loading custom model...'), findsOneWidget);
    });

    testWidgets('render_withProgress_showsProgress', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const LoadingIndicator(
            phase: LoadingPhase.loadingModel,
            progress: 0.5,
          ),
        ),
      );

      expect(find.text('50%'), findsOneWidget);
    });
  });
}
