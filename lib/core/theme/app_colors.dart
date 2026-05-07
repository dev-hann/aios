import 'package:aios/domain/entities/service_state.dart';
import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const background = Color(0xFF0E0E10);
  static const surface = Color(0xFF18181B);
  static const surfaceElevated = Color(0xFF1F1F23);
  static const surfaceModal = Color(0xFF252528);
  static const cardBackground = Color(0xFF18181B);
  static const primary = Color(0xFF9146FF);
  static const primaryHover = Color(0xFFA970FF);
  static const secondary = Color(0xFFBF94FF);
  static const textPrimary = Color(0xFFEFEFF1);
  static const textSecondary = Color(0xFFADADB8);
  static const error = Color(0xFFEB0400);
  static const success = Color(0xFF00C853);
  static const warning = Color(0xFFFFCA28);
  static const divider = Color(0xFF2F2F35);
  static const userBubble = Color(0xFF9146FF);
  static const assistantBubble = Color(0xFF1F1F23);
  static const sliderActive = Color(0xFF9146FF);
  static const sliderInactive = Color(0xFF2F2F35);
  static const idle = Color(0xFFADADB8);
  static const ready = Color(0xFF00C853);
  static const generating = Color(0xFFFFCA28);
  static const loadingModel = Color(0xFF2F81F7);

  static Color stateColor(ServiceState? serviceState) {
    switch (serviceState) {
      case ServiceState.idle:
        return idle;
      case ServiceState.loadingModel:
        return loadingModel;
      case ServiceState.ready:
        return ready;
      case ServiceState.generating:
        return generating;
      case ServiceState.error:
        return error;
      case null:
        return idle;
    }
  }

  static String stateLabel(ServiceState? serviceState) {
    switch (serviceState) {
      case ServiceState.idle:
        return 'Idle';
      case ServiceState.loadingModel:
        return 'Loading Model...';
      case ServiceState.ready:
        return 'Ready';
      case ServiceState.generating:
        return 'Generating...';
      case ServiceState.error:
        return 'Error';
      case null:
        return 'Unknown';
    }
  }
}

class AppRadius {
  const AppRadius._();

  static const double xs = 2;
  static const double sm = 4;
  static const double md = 6;
  static const double lg = 10;
  static const double xl = 12;
  static const double full = 9999;
}

class LightColors {
  const LightColors._();

  static const background = Color(0xFFF7F7F8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceElevated = Color(0xFFEFEFF1);
  static const surfaceModal = Color(0xFFF0F0F2);
  static const cardBackground = Color(0xFFFFFFFF);
  static const primary = Color(0xFF7C3AED);
  static const primaryHover = Color(0xFF6D28D9);
  static const secondary = Color(0xFF8B5CF6);
  static const textPrimary = Color(0xFF18181B);
  static const textSecondary = Color(0xFF71717A);
  static const error = Color(0xFFDC2626);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFCA8A04);
  static const divider = Color(0xFFE4E4E7);
  static const userBubble = Color(0xFF7C3AED);
  static const assistantBubble = Color(0xFFF0F0F2);
  static const sliderActive = Color(0xFF7C3AED);
  static const sliderInactive = Color(0xFFE4E4E7);
}

class AppSpacing {
  const AppSpacing._();

  static const double base = 4;
  static const double s = 8;
  static const double m = 10;
  static const double l = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}
