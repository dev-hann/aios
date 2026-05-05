import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppColors', () {
    test('background_shouldHaveCorrectValue', () {
      expect(AppColors.background, const Color(0xFF0D0D1A));
    });

    test('surface_shouldHaveCorrectValue', () {
      expect(AppColors.surface, const Color(0xFF1A1A2E));
    });

    test('surfaceVariant_shouldHaveCorrectValue', () {
      expect(AppColors.surfaceVariant, const Color(0xFF252540));
    });

    test('primary_shouldHaveCorrectValue', () {
      expect(AppColors.primary, const Color(0xFF6C63FF));
    });

    test('secondary_shouldHaveCorrectValue', () {
      expect(AppColors.secondary, const Color(0xFF9D4EDD));
    });

    test('textPrimary_shouldHaveCorrectValue', () {
      expect(AppColors.textPrimary, const Color(0xFFE0E0E0));
    });

    test('textSecondary_shouldHaveCorrectValue', () {
      expect(AppColors.textSecondary, const Color(0xFF9E9E9E));
    });

    test('error_shouldHaveCorrectValue', () {
      expect(AppColors.error, const Color(0xFFFF6B6B));
    });

    test('success_shouldHaveCorrectValue', () {
      expect(AppColors.success, const Color(0xFF4ADE80));
    });

    test('warning_shouldHaveCorrectValue', () {
      expect(AppColors.warning, const Color(0xFFFBBF24));
    });

    test('divider_shouldHaveCorrectValue', () {
      expect(AppColors.divider, const Color(0xFF333355));
    });

    test('cardBackground_shouldHaveCorrectValue', () {
      expect(AppColors.cardBackground, const Color(0xFF1A1A2E));
    });

    test('sliderActive_shouldHaveCorrectValue', () {
      expect(AppColors.sliderActive, const Color(0xFF6C63FF));
    });

    test('sliderInactive_shouldHaveCorrectValue', () {
      expect(AppColors.sliderInactive, const Color(0xFF252540));
    });
  });

  group('aiosTheme', () {
    test('shouldUseDarkBrightness', () {
      expect(aiosTheme.brightness, Brightness.dark);
    });

    test('scaffoldBackground_shouldBeDarkBackground', () {
      expect(aiosTheme.scaffoldBackgroundColor, AppColors.background);
    });

    test('colorScheme_primary_shouldMatchAppColors', () {
      expect(aiosTheme.colorScheme.primary, AppColors.primary);
    });

    test('colorScheme_secondary_shouldMatchAppColors', () {
      expect(aiosTheme.colorScheme.secondary, AppColors.secondary);
    });

    test('colorScheme_surface_shouldMatchAppColors', () {
      expect(aiosTheme.colorScheme.surface, AppColors.surface);
    });

    test('colorScheme_error_shouldMatchAppColors', () {
      expect(aiosTheme.colorScheme.error, AppColors.error);
    });

    test('appBarTheme_background_shouldBeSurface', () {
      expect(aiosTheme.appBarTheme.backgroundColor, AppColors.surface);
    });

    test('appBarTheme_foregroundColor_shouldBeTextPrimary', () {
      expect(aiosTheme.appBarTheme.foregroundColor, AppColors.textPrimary);
    });

    test('cardTheme_color_shouldBeSurface', () {
      expect(aiosTheme.cardTheme.color, AppColors.surface);
    });
  });
}
