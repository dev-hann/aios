import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:flutter/material.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({
    required this.serviceState,
    this.contextUsage,
    super.key,
  });

  final ServiceState serviceState;
  final String? contextUsage;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.stateColor(serviceState);
    final label = AppColors.stateLabel(serviceState);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (contextUsage != null && serviceState == ServiceState.ready) ...[
          const SizedBox(width: 8),
          Text(
            contextUsage!,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}
