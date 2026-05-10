import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/core/theme/app_strings.dart';
import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:aios/domain/entities/update_info.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/providers/settings_state.dart';
import 'package:aios/presentation/providers/update_provider.dart';
import 'package:aios/presentation/providers/update_state.dart';
import 'package:aios/presentation/widgets/connection_status_badge.dart';
import 'package:aios/presentation/widgets/nav_tile.dart';
import 'package:aios/presentation/widgets/section_card.dart';
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
        title: Text(Strings.settings.title),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _ProviderSection(state: state),
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

class _ProviderSection extends StatelessWidget {
  const _ProviderSection({required this.state});

  final SettingsState state;

  @override
  Widget build(BuildContext context) {
    final config = state.providerConfig;

    return SectionCard(
      title: Strings.settings.provider,
      icon: Icons.cloud,
      child: Column(
        children: [
          if (config != null)
            _ConnectedRow(config: config)
          else
            _NotConnectedRow(),
          const SizedBox(height: 12),
          ConnectionStatusBadge(
            config: config,
            onTap: () => context.push('/settings/provider'),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: Semantics(
              label: 'provider_settings_button',
              button: true,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/settings/provider'),
                icon: const Icon(Icons.settings, size: 18),
                label: Text(
                  config != null
                      ? Strings.settings.providerSettings
                      : Strings.settings.setupProvider,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectedRow extends StatelessWidget {
  const _ConnectedRow({required this.config});

  final LlmProviderConfig config;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: AppColors.success, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                config.model,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                Strings.provider.nameForType(config.type),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotConnectedRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.cloud_off, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Strings.settings.noProvider,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              Text(
                Strings.settings.needSetup,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InferenceNavTile extends StatelessWidget {
  const _InferenceNavTile({required this.state});

  final SettingsState state;

  @override
  Widget build(BuildContext context) {
    return NavTile(
      icon: Icons.tune,
      title: Strings.settings.inference,
      subtitle: Strings.inferenceNav.summary(
        state.temperature,
        state.maxTokens,
      ),
      semanticsLabel: 'settings_inference_tile',
      onTap: () => context.push('/settings/inference'),
    );
  }
}

class _PermissionNavTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return NavTile(
      icon: Icons.security,
      title: Strings.settings.permissions,
      subtitle: Strings.settings.managePermissions,
      semanticsLabel: 'settings_permissions_tile',
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

    return SectionCard(
      title: Strings.settings.appInfo,
      icon: Icons.info_outline,
      child: Column(
        children: [
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(Strings.settings.version),
            trailing: Text(
              _version.isNotEmpty ? _version : Strings.appInfo.loading,
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
    return switch (state.status) {
      UpdateStatus.idle => SizedBox(
        width: double.infinity,
        child: Semantics(
          label: 'check_for_updates_button',
          button: true,
          child: OutlinedButton.icon(
            onPressed: () => ref.read(updateProvider.notifier).checkForUpdate(),
            icon: const Icon(Icons.system_update, size: 18),
            label: Text(Strings.settings.checkUpdates),
          ),
        ),
      ),
      UpdateStatus.checking => Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            Strings.settings.checkingUpdates,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
      UpdateStatus.available => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${Strings.settings.updateAvailable}: '
            'v${state.updateInfo?.latestVersion ?? '?'}',
            style: const TextStyle(
              color: AppColors.success,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            state.updateInfo?.releaseNotes ?? '',
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
              onPressed: () => ref.read(updateProvider.notifier).downloadApk(),
              icon: const Icon(Icons.download, size: 18),
              label: Text(Strings.settings.download),
            ),
          ),
        ],
      ),
      UpdateStatus.downloading => Column(
        children: [
          LinearProgressIndicator(
            value: state.downloadProgress,
            backgroundColor: AppColors.sliderInactive,
            color: AppColors.primary,
          ),
          const SizedBox(height: 4),
          Text(
            '${Strings.settings.downloading} '
            '${(state.downloadProgress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
      UpdateStatus.downloaded => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => ref.read(updateProvider.notifier).installApk(),
          icon: const Icon(Icons.install_mobile, size: 18),
          label: Text(Strings.settings.installUpdate),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: AppColors.textPrimary,
          ),
        ),
      ),
      UpdateStatus.installing => Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            Strings.settings.installing,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
      UpdateStatus.installed => Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 18),
          const SizedBox(width: 8),
          Text(
            Strings.settings.updateInstalled,
            style: const TextStyle(color: AppColors.success, fontSize: 13),
          ),
        ],
      ),
      UpdateStatus.notAvailable => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                Strings.settings.upToDate,
                style: const TextStyle(color: AppColors.success, fontSize: 13),
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
              label: Text(Strings.settings.checkAgain),
            ),
          ),
        ],
      ),
      UpdateStatus.error => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.errorMessage ?? Strings.appInfo.unknownError,
            style: const TextStyle(color: AppColors.error, fontSize: 13),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  ref.read(updateProvider.notifier).checkForUpdate(),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(Strings.chat.retry),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    };
  }
}
