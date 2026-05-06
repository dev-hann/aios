import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppColors', () {
    test('background_shouldHaveCorrectValue', () {
      expect(AppColors.background, const Color(0xFF0E0E10));
    });

    test('surface_shouldHaveCorrectValue', () {
      expect(AppColors.surface, const Color(0xFF18181B));
    });

    test('surfaceElevated_shouldHaveCorrectValue', () {
      expect(AppColors.surfaceElevated, const Color(0xFF1F1F23));
    });

    test('primary_shouldHaveCorrectValue', () {
      expect(AppColors.primary, const Color(0xFF9146FF));
    });

    test('secondary_shouldHaveCorrectValue', () {
      expect(AppColors.secondary, const Color(0xFFBF94FF));
    });

    test('textPrimary_shouldHaveCorrectValue', () {
      expect(AppColors.textPrimary, const Color(0xFFEFEFF1));
    });

    test('textSecondary_shouldHaveCorrectValue', () {
      expect(AppColors.textSecondary, const Color(0xFFADADB8));
    });

    test('error_shouldHaveCorrectValue', () {
      expect(AppColors.error, const Color(0xFFEB0400));
    });

    test('success_shouldHaveCorrectValue', () {
      expect(AppColors.success, const Color(0xFF00C853));
    });

    test('warning_shouldHaveCorrectValue', () {
      expect(AppColors.warning, const Color(0xFFFFCA28));
    });

    test('divider_shouldHaveCorrectValue', () {
      expect(AppColors.divider, const Color(0xFF2F2F35));
    });

    test('cardBackground_shouldHaveCorrectValue', () {
      expect(AppColors.cardBackground, const Color(0xFF18181B));
    });

    test('sliderActive_shouldHaveCorrectValue', () {
      expect(AppColors.sliderActive, const Color(0xFF9146FF));
    });

    test('sliderInactive_shouldHaveCorrectValue', () {
      expect(AppColors.sliderInactive, const Color(0xFF2F2F35));
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

  group('AppRadius', () {
    test('xs_shouldBe2', () {
      expect(AppRadius.xs, 2);
    });

    test('sm_shouldBe4', () {
      expect(AppRadius.sm, 4);
    });

    test('md_shouldBe6', () {
      expect(AppRadius.md, 6);
    });

    test('lg_shouldBe10', () {
      expect(AppRadius.lg, 10);
    });
  });

  group('AppSpacing', () {
    test('base_shouldBe4', () {
      expect(AppSpacing.base, 4);
    });

    test('s_shouldBe8', () {
      expect(AppSpacing.s, 8);
    });

    test('l_shouldBe16', () {
      expect(AppSpacing.l, 16);
    });
  });
}
