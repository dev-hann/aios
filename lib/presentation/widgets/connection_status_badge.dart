import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/core/theme/app_strings.dart';
import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:flutter/material.dart';

class ConnectionStatusBadge extends StatelessWidget {
  const ConnectionStatusBadge({required this.config, this.onTap, super.key});

  final LlmProviderConfig? config;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isConnected = config != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isConnected
              ? AppColors.success.withValues(alpha: 0.15)
              : AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: isConnected
                ? AppColors.success.withValues(alpha: 0.3)
                : AppColors.error.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isConnected ? AppColors.success : AppColors.error,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              isConnected ? config?.model ?? '' : Strings.chat.settingsNeeded,
              style: TextStyle(
                color: isConnected ? AppColors.success : AppColors.error,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
