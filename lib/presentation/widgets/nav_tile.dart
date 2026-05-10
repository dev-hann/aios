import 'package:aios/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class NavTile extends StatelessWidget {
  const NavTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.trailing,
    this.semanticsLabel,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Card(
        color: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.divider),
        ),
        child: Semantics(
          label: semanticsLabel,
          button: true,
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            leading: Icon(icon, color: AppColors.primary, size: 20),
            title: Text(title, style: const TextStyle(fontSize: 14)),
            subtitle: subtitle != null
                ? Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  )
                : null,
            trailing:
                trailing ??
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}
