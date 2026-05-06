import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/domain/entities/update_info.dart';
import 'package:aios/presentation/providers/update_provider.dart';
import 'package:aios/presentation/providers/update_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UpdateScreen extends ConsumerWidget {
  const UpdateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateProvider);
    final currentVersion = ref.watch(currentVersionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Update'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusContent(
              state: state,
              currentVersion: currentVersion,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusContent extends ConsumerWidget {
  const _StatusContent({
    required this.state,
    required this.currentVersion,
  });

  final UpdateState state;
  final String currentVersion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (state.status) {
      UpdateStatus.idle => _IdleView(
          currentVersion: currentVersion,
          onCheck: () => ref.read(updateProvider.notifier).checkForUpdate(),
        ),
      UpdateStatus.checking => const _CheckingView(),
      UpdateStatus.available => _AvailableView(
          info: state.updateInfo!,
          onDownload: () => ref.read(updateProvider.notifier).downloadApk(),
        ),
      UpdateStatus.downloading =>
        _DownloadingView(progress: state.downloadProgress),
      UpdateStatus.downloaded => _DownloadedView(
          onInstall: () => ref.read(updateProvider.notifier).installApk(),
        ),
      UpdateStatus.installed => const _InstalledView(),
      UpdateStatus.installing => const _InstallingView(),
      UpdateStatus.notAvailable => _NotAvailableView(
          onRetry: () => ref.read(updateProvider.notifier).checkForUpdate(),
        ),
      UpdateStatus.error => _ErrorView(
          message: state.errorMessage ?? 'Unknown error',
          onRetry: () => ref.read(updateProvider.notifier).checkForUpdate(),
        ),
    };
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({
    required this.currentVersion,
    required this.onCheck,
  });

  final String currentVersion;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.system_update,
          size: 64,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 24),
        Text(
          'v$currentVersion',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: onCheck,
          icon: const Icon(Icons.search),
          label: const Text('Check for Update'),
        ),
      ],
    );
  }
}

class _CheckingView extends StatelessWidget {
  const _CheckingView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        CircularProgressIndicator(color: AppColors.primary),
        SizedBox(height: 24),
        Text(
          'Checking for updates...',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      ],
    );
  }
}

class _AvailableView extends StatelessWidget {
  const _AvailableView({
    required this.info,
    required this.onDownload,
  });

  final UpdateInfo info;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.new_releases,
          size: 64,
          color: AppColors.success,
        ),
        const SizedBox(height: 16),
        const Text(
          'Update Available',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'v${info.latestVersion}',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          info.releaseNotes,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          textAlign: TextAlign.center,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: onDownload,
          icon: const Icon(Icons.download),
          label: const Text('Download'),
        ),
      ],
    );
  }
}

class _DownloadingView extends StatelessWidget {
  const _DownloadingView({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.download,
          size: 48,
          color: AppColors.primary,
        ),
        const SizedBox(height: 24),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: AppColors.sliderInactive,
          color: AppColors.primary,
        ),
        const SizedBox(height: 8),
        Text(
          '${(progress * 100).toStringAsFixed(0)}%',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _DownloadedView extends StatelessWidget {
  const _DownloadedView({required this.onInstall});

  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.check_circle,
          size: 64,
          color: AppColors.success,
        ),
        const SizedBox(height: 16),
        const Text(
          'Download Complete',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: onInstall,
          icon: const Icon(Icons.install_mobile),
          label: const Text('Install'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _InstalledView extends StatelessWidget {
  const _InstalledView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Icon(
          Icons.system_update,
          size: 64,
          color: AppColors.success,
        ),
        SizedBox(height: 16),
        Text(
          'Update installed',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'The app will restart shortly.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      ],
    );
  }
}

class _InstallingView extends StatelessWidget {
  const _InstallingView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        CircularProgressIndicator(color: AppColors.primary),
        SizedBox(height: 24),
        Text(
          'Installing update...',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      ],
    );
  }
}

class _NotAvailableView extends StatelessWidget {
  const _NotAvailableView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 64,
          color: AppColors.success,
        ),
        const SizedBox(height: 16),
        const Text(
          'Already up to date',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Check Again'),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.error_outline,
          size: 64,
          color: AppColors.error,
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: const TextStyle(
            color: AppColors.error,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
