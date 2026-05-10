import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppColors', () {
    test('appColors_background_hasCorrectValue', () {
      expect(AppColors.background, const Color(0xFF0E0E10));
    });

    test('appColors_surface_hasCorrectValue', () {
      expect(AppColors.surface, const Color(0xFF18181B));
    });

    test('appColors_surfaceElevated_hasCorrectValue', () {
      expect(AppColors.surfaceElevated, const Color(0xFF1F1F23));
    });

    test('appColors_primary_hasCorrectValue', () {
      expect(AppColors.primary, const Color(0xFF9146FF));
    });

    test('appColors_secondary_hasCorrectValue', () {
      expect(AppColors.secondary, const Color(0xFFBF94FF));
    });

    test('appColors_textPrimary_hasCorrectValue', () {
      expect(AppColors.textPrimary, const Color(0xFFEFEFF1));
    });

    test('appColors_textSecondary_hasCorrectValue', () {
      expect(AppColors.textSecondary, const Color(0xFFADADB8));
    });

    test('appColors_error_hasCorrectValue', () {
      expect(AppColors.error, const Color(0xFFEB0400));
    });

    test('appColors_success_hasCorrectValue', () {
      expect(AppColors.success, const Color(0xFF00C853));
    });

    test('appColors_warning_hasCorrectValue', () {
      expect(AppColors.warning, const Color(0xFFFFCA28));
    });

    test('appColors_divider_hasCorrectValue', () {
      expect(AppColors.divider, const Color(0xFF2F2F35));
    });

    test('appColors_cardBackground_hasCorrectValue', () {
      expect(AppColors.cardBackground, const Color(0xFF18181B));
    });

    test('appColors_sliderActive_hasCorrectValue', () {
      expect(AppColors.sliderActive, const Color(0xFF9146FF));
    });

    test('appColors_sliderInactive_hasCorrectValue', () {
      expect(AppColors.sliderInactive, const Color(0xFF2F2F35));
    });
  });

  group('aiosDarkTheme', () {
    test('aiosDarkTheme_usesDarkBrightness', () {
      expect(aiosDarkTheme.brightness, Brightness.dark);
    });

    test('aiosDarkTheme_scaffoldBackground_isDarkBackground', () {
      expect(aiosDarkTheme.scaffoldBackgroundColor, AppColors.background);
    });

    test('aiosDarkTheme_colorSchemePrimary_matchesAppColors', () {
      expect(aiosDarkTheme.colorScheme.primary, AppColors.primary);
    });

    test('aiosDarkTheme_colorSchemeSecondary_matchesAppColors', () {
      expect(aiosDarkTheme.colorScheme.secondary, AppColors.secondary);
    });

    test('aiosDarkTheme_colorSchemeSurface_matchesAppColors', () {
      expect(aiosDarkTheme.colorScheme.surface, AppColors.surface);
    });

    test('aiosDarkTheme_colorSchemeError_matchesAppColors', () {
      expect(aiosDarkTheme.colorScheme.error, AppColors.error);
    });

    test('aiosDarkTheme_appBarBackground_isSurface', () {
      expect(aiosDarkTheme.appBarTheme.backgroundColor, AppColors.surface);
    });

    test('aiosDarkTheme_appBarForeground_isTextPrimary', () {
      expect(aiosDarkTheme.appBarTheme.foregroundColor, AppColors.textPrimary);
    });

    test('aiosDarkTheme_cardThemeColor_isSurface', () {
      expect(aiosDarkTheme.cardTheme.color, AppColors.surface);
    });
  });

  group('AppRadius', () {
    test('appRadius_xs_is2', () {
      expect(AppRadius.xs, 2);
    });

    test('appRadius_sm_is4', () {
      expect(AppRadius.sm, 4);
    });

    test('appRadius_md_is6', () {
      expect(AppRadius.md, 6);
    });

    test('appRadius_lg_is10', () {
      expect(AppRadius.lg, 10);
    });
  });

  group('AppSpacing', () {
    test('appSpacing_base_is4', () {
      expect(AppSpacing.base, 4);
    });

    test('appSpacing_s_is8', () {
      expect(AppSpacing.s, 8);
    });

    test('appSpacing_l_is16', () {
      expect(AppSpacing.l, 16);
    });
  });
}
