import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/core/theme/app_strings.dart';
import 'package:flutter/material.dart';

enum LoadingPhase { initializing, loadingModel, preparing, ready }

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    required this.phase,
    this.message,
    this.progress,
    super.key,
  });

  final LoadingPhase phase;
  final String? message;
  final double? progress;

  static String _defaultLabel(LoadingPhase phase) {
    return switch (phase) {
      LoadingPhase.initializing => Strings.loading.initializing,
      LoadingPhase.loadingModel => Strings.loading.loadingModel,
      LoadingPhase.preparing => Strings.loading.preparing,
      LoadingPhase.ready => Strings.loading.ready,
    };
  }

  @override
  Widget build(BuildContext context) {
    final label = message ?? _defaultLabel(phase);
    final isReady = phase == LoadingPhase.ready;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isReady)
            const Icon(Icons.check_circle, size: 48, color: AppColors.success)
          else
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            ),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (progress != null && !isReady) ...[
            const SizedBox(height: 8),
            Text(
              '${(progress! * 100).round()}%',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
