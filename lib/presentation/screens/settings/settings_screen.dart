import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/domain/entities/update_info.dart';

import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/providers/settings_state.dart';
import 'package:aios/presentation/providers/update_provider.dart';
import 'package:aios/presentation/providers/update_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _ModelNavTile(state: state),
          const SizedBox(height: 8),
          _InferenceNavTile(state: state),
          const SizedBox(height: 8),
          _PermissionNavTile(),
          const SizedBox(height: 8),
          _AppInfoSection(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        color: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.divider),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

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
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          leading: Icon(icon, color: AppColors.primary, size: 20),
          title: Text(
            title,
            style: const TextStyle(fontSize: 14),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                )
              : null,
          trailing: trailing ??
              const Icon(Icons.chevron_right,
                  color: AppColors.textSecondary, size: 20),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _ModelNavTile extends StatelessWidget {
  const _ModelNavTile({required this.state});

  final SettingsState state;

  @override
  Widget build(BuildContext context) {
    final activeName = _activeModelName();
    final subtitle = activeName ?? 'No model loaded';

    return _NavTile(
      icon: Icons.psychology,
      title: 'Model',
      subtitle: subtitle,
      onTap: () => context.push('/settings/model'),
      trailing: state.isLoadingModel
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          : null,
    );
  }

  String? _activeModelName() {
    if (state.lastModelPath == null) return null;
    final model = state.availableModels
        .where((m) => m.path == state.lastModelPath)
        .firstOrNull;
    return model?.name;
  }
}

class _InferenceNavTile extends StatelessWidget {
  const _InferenceNavTile({required this.state});

  final SettingsState state;

  @override
  Widget build(BuildContext context) {
    return _NavTile(
      icon: Icons.tune,
      title: 'Inference',
      subtitle:
          'Temp ${state.temperature.toStringAsFixed(1)} · MaxTok ${state.maxTokens} · Ctx ${state.contextSize}',
      onTap: () => context.push('/settings/inference'),
    );
  }
}

class _PermissionNavTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _NavTile(
      icon: Icons.security,
      title: 'Permissions',
      subtitle: 'Manage app permissions',
      onTap: () => context.push('/settings/permissions'),
    );
  }
}

class _AppInfoSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AppInfoSection> createState() => _AppInfoSectionState();
}

class _AppInfoSectionState extends ConsumerState<_AppInfoSection> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = '${info.version} (${info.buildNumber})';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(updateProvider);

    return _SectionCard(
      title: 'App Info',
      icon: Icons.info_outline,
      child: Column(
        children: [
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Version'),
            trailing: Text(
              _version.isNotEmpty ? _version : 'Loading...',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          _InlineUpdateStatus(state: updateState),
          const SizedBox(height: 8),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('GitHub'),
            trailing: const Icon(
              Icons.open_in_new,
              color: AppColors.primary,
              size: 20,
            ),
            onTap: () async {
              final uri = Uri.parse('https://github.com/dev-hann/aios');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _InlineUpdateStatus extends ConsumerWidget {
  const _InlineUpdateStatus({required this.state});

  final UpdateState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = state.status;
    if (status == UpdateStatus.idle) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () =>
              ref.read(updateProvider.notifier).checkForUpdate(),
          icon: const Icon(Icons.system_update, size: 18),
          label: const Text('Check for Updates'),
        ),
      );
    }
    if (status == UpdateStatus.checking) {
      return const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Checking for updates...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      );
    }
    if (status == UpdateStatus.available) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Update available: v${state.updateInfo!.latestVersion}',
            style: const TextStyle(
              color: AppColors.success,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            state.updateInfo!.releaseNotes,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  ref.read(updateProvider.notifier).downloadApk(),
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Download'),
            ),
          ),
        ],
      );
    }
    if (status == UpdateStatus.downloading) {
      return Column(
        children: [
          LinearProgressIndicator(
            value: state.downloadProgress,
            backgroundColor: AppColors.sliderInactive,
            color: AppColors.primary,
          ),
          const SizedBox(height: 4),
          Text(
            'Downloading... ${(state.downloadProgress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      );
    }
    if (status == UpdateStatus.downloaded) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () =>
              ref.read(updateProvider.notifier).installApk(),
          icon: const Icon(Icons.install_mobile, size: 18),
          label: const Text('Install Update'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: AppColors.textPrimary,
          ),
        ),
      );
    }
    if (status == UpdateStatus.installing) {
      return const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Installing update...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      );
    }
    if (status == UpdateStatus.installed) {
      return const Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 18),
          SizedBox(width: 8),
          Text(
            'Update installed — app will restart',
            style: TextStyle(color: AppColors.success, fontSize: 13),
          ),
        ],
      );
    }
    if (status == UpdateStatus.notAvailable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_outline,
                  color: AppColors.success, size: 18),
              SizedBox(width: 8),
              Text(
                'Already up to date',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  ref.read(updateProvider.notifier).checkForUpdate(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Check Again'),
            ),
          ),
        ],
      );
    }
    if (status == UpdateStatus.error) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.errorMessage ?? 'Unknown error',
            style: const TextStyle(color: AppColors.error, fontSize: 13),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  ref.read(updateProvider.notifier).checkForUpdate(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
