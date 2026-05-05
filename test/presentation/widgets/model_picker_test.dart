import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/domain/entities/model_info.dart';
import 'package:aios/presentation/widgets/model_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget _buildModelPicker({
    List<ModelInfo> models = const [],
    bool isLoading = false,
    ValueChanged<ModelInfo>? onModelSelected,
    VoidCallback? onImport,
  }) {
    return MaterialApp(
      home: Material(
        child: ModelPicker(
          models: models,
          onModelSelected: onModelSelected ?? (_) {},
          onImport: onImport ?? () {},
          isLoading: isLoading,
        ),
      ),
    );
  }

  group('ModelPicker', () {
    testWidgets(
      'build_isLoadingTrue_showsProgressBar',
      (tester) async {
        await tester.pumpWidget(_buildModelPicker(isLoading: true));

        expect(
          find.byType(CircularProgressIndicator),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'build_emptyModels_showsOnlyImportTile',
      (tester) async {
        await tester.pumpWidget(_buildModelPicker());

        expect(find.text('Import Model'), findsOneWidget);
        expect(find.byType(ListTile), findsOneWidget);
      },
    );

    testWidgets(
      'build_withModel_showsSizeInMB',
      (tester) async {
        final models = [
          const ModelInfo(
            name: 'test.gguf',
            size: 52428800,
            path: '/test.gguf',
          ),
        ];

        await tester.pumpWidget(_buildModelPicker(models: models));

        expect(find.text('test.gguf'), findsOneWidget);
        expect(find.text('50.0 MB'), findsOneWidget);
      },
    );

    testWidgets(
      'build_withSmallModel_showsSizeInBytes',
      (tester) async {
        final models = [
          const ModelInfo(
            name: 'tiny.gguf',
            size: 500,
            path: '/tiny.gguf',
          ),
        ];

        await tester.pumpWidget(_buildModelPicker(models: models));

        expect(find.text('500 B'), findsOneWidget);
      },
    );

    testWidgets(
      'build_withLargeModel_showsSizeInGB',
      (tester) async {
        final models = [
          const ModelInfo(
            name: 'big.gguf',
            size: 2147483648,
            path: '/big.gguf',
          ),
        ];

        await tester.pumpWidget(_buildModelPicker(models: models));

        expect(find.text('2.0 GB'), findsOneWidget);
      },
    );

    testWidgets(
      'build_tapModel_callsOnModelSelected',
      (tester) async {
        final models = [
          const ModelInfo(
            name: 'test.gguf',
            size: 1024,
            path: '/test.gguf',
          ),
        ];
        ModelInfo? selected;

        await tester.pumpWidget(
          _buildModelPicker(
            models: models,
            onModelSelected: (m) => selected = m,
          ),
        );

        await tester.tap(find.text('test.gguf'));
        await tester.pump();

        expect(selected, isNotNull);
        expect(selected!.name, 'test.gguf');
      },
    );

    testWidgets(
      'build_tapImport_callsOnImport',
      (tester) async {
        var importCalled = false;

        await tester.pumpWidget(
          _buildModelPicker(onImport: () => importCalled = true),
        );

        await tester.tap(find.text('Import Model'));
        await tester.pump();

        expect(importCalled, isTrue);
      },
    );

    testWidgets(
      'build_withKBSize_showsSizeInKB',
      (tester) async {
        final models = [
          const ModelInfo(
            name: 'mid.gguf',
            size: 153600,
            path: '/mid.gguf',
          ),
        ];

        await tester.pumpWidget(_buildModelPicker(models: models));

        expect(find.text('150.0 KB'), findsOneWidget);
      },
    );
  });
}
