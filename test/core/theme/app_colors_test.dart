import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('stateColor', () {
    test('stateColor_idle_returnsIdleColor', () {
      expect(AppColors.stateColor(ServiceState.idle), AppColors.idle);
    });

    test('stateColor_loadingModel_returnsLoadingModelColor', () {
      expect(
        AppColors.stateColor(ServiceState.loadingModel),
        AppColors.loadingModel,
      );
    });

    test('stateColor_ready_returnsReadyColor', () {
      expect(AppColors.stateColor(ServiceState.ready), AppColors.ready);
    });

    test('stateColor_generating_returnsGeneratingColor', () {
      expect(
        AppColors.stateColor(ServiceState.generating),
        AppColors.generating,
      );
    });

    test('stateColor_error_returnsErrorColor', () {
      expect(AppColors.stateColor(ServiceState.error), AppColors.error);
    });

    test('stateColor_null_returnsIdleColor', () {
      expect(AppColors.stateColor(null), AppColors.idle);
    });
  });

  group('stateLabel', () {
    test('stateLabel_idle_returnsIdleLabel', () {
      expect(AppColors.stateLabel(ServiceState.idle), 'Idle');
    });

    test('stateLabel_loadingModel_returnsLoadingModelLabel', () {
      expect(
        AppColors.stateLabel(ServiceState.loadingModel),
        'Loading Model...',
      );
    });

    test('stateLabel_ready_returnsReadyLabel', () {
      expect(AppColors.stateLabel(ServiceState.ready), 'Ready');
    });

    test('stateLabel_generating_returnsGeneratingLabel', () {
      expect(
        AppColors.stateLabel(ServiceState.generating),
        'Generating...',
      );
    });

    test('stateLabel_error_returnsErrorLabel', () {
      expect(AppColors.stateLabel(ServiceState.error), 'Error');
    });

    test('stateLabel_null_returnsUnknownLabel', () {
      expect(AppColors.stateLabel(null), 'Unknown');
    });
  });
}
