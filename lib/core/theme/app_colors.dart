import 'package:aios/domain/entities/service_state.dart';
import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const background = Color(0xFF0D0D1A);
  static const surface = Color(0xFF1A1A2E);
  static const surfaceVariant = Color(0xFF252540);
  static const cardBackground = Color(0xFF1A1A2E);
  static const primary = Color(0xFF6C63FF);
  static const secondary = Color(0xFF9D4EDD);
  static const textPrimary = Color(0xFFE0E0E0);
  static const textSecondary = Color(0xFF9E9E9E);
  static const error = Color(0xFFFF6B6B);
  static const success = Color(0xFF4ADE80);
  static const warning = Color(0xFFFBBF24);
  static const divider = Color(0xFF333355);
  static const userBubble = Color(0xFF6C63FF);
  static const assistantBubble = Color(0xFF1E1E36);
  static const sliderActive = Color(0xFF6C63FF);
  static const sliderInactive = Color(0xFF252540);
  static const idle = Color(0xFF9E9E9E);
  static const ready = Color(0xFF4CAF50);
  static const generating = Color(0xFFFFC107);
  static const loadingModel = Color(0xFF2196F3);

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
