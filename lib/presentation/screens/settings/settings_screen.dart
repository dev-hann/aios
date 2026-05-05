import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/domain/entities/model_info.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/providers/settings_state.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
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
          _ModelSection(state: state),
          const _SectionDivider(),
          _InferenceSection(state: state),
          const _SectionDivider(),
          _AgentSection(state: state),
          const _SectionDivider(),
          _AppInfoSection(),
          const _SectionDivider(),
          _AboutSection(),
        ],
      ),
    );
  }
}

class _ModelSection extends ConsumerWidget {
  const _ModelSection({required this.state});

  final SettingsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SectionCard(
      title: 'Model Management',
      icon: Icons.psychology,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.isLoadingModel)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(
                color: AppColors.primary,
              ),
            ),
          if (state.availableModels.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No models found',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            ...state.availableModels.map(
              (model) => _ModelTile(model: model),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _requestStoragePermission(context);
                    if (context.mounted) {
                      ref
                          .read(settingsProvider.notifier)
                          .scanModels();
                    }
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Scan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showImportDialog(context, ref);
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Import'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot access file path')),
          );
        }
        return;
      }

      final success = await ref
          .read(settingsProvider.notifier)
          .importModel(file.path!, file.name);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Model imported: ${file.name}'
                  : 'Failed to import model',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }
}

class _ModelTile extends ConsumerWidget {
  const _ModelTile({required this.model});

  final ModelInfo model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final isActive = state.lastModelPath == model.path;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isActive ? Icons.check_circle : Icons.circle_outlined,
        color: isActive ? AppColors.primary : AppColors.textSecondary,
        size: 20,
      ),
      title: Text(
        model.name,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        _formatSize(model.size),
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing: isActive
          ? null
          : TextButton(
              onPressed: () {
                ref
                    .read(settingsProvider.notifier)
                    .loadModel(model.path);
              },
              child: const Text('Load'),
            ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }
}

class _InferenceSection extends ConsumerWidget {
  const _InferenceSection({required this.state});

  final SettingsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SectionCard(
      title: 'Inference Parameters',
      icon: Icons.tune,
      child: Column(
        children: [
          _SliderTile(
            label: 'Context Size',
            value: state.contextSize.toDouble(),
            min: 512,
            max: 8192,
            divisions: 15,
            displayValue: '${state.contextSize}',
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).updateContextSize(v.round()),
          ),
          _SliderTile(
            label: 'Temperature',
            value: state.temperature,
            min: 0.0,
            max: 2.0,
            divisions: 20,
            displayValue: state.temperature.toStringAsFixed(2),
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).updateTemperature(v),
          ),
          _SliderTile(
            label: 'Max Tokens',
            value: state.maxTokens.toDouble(),
            min: 64,
            max: 2048,
            divisions: 18,
            displayValue: '${state.maxTokens}',
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).updateMaxTokens(v.round()),
          ),
          _SliderTile(
            label: 'Top-K',
            value: state.topK.toDouble(),
            min: 1,
            max: 100,
            divisions: 99,
            displayValue: '${state.topK}',
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).updateTopK(v.round()),
          ),
          _SliderTile(
            label: 'Top-P',
            value: state.topP,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            displayValue: state.topP.toStringAsFixed(2),
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).updateTopP(v),
          ),
          _SliderTile(
            label: 'Repeat Penalty',
            value: state.repeatPenalty,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            displayValue: state.repeatPenalty.toStringAsFixed(2),
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).updateRepeatPenalty(v),
          ),
        ],
      ),
    );
  }
}

class _AgentSection extends ConsumerWidget {
  const _AgentSection({required this.state});

  final SettingsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SectionCard(
      title: 'Agent Settings',
      icon: Icons.smart_toy,
      child: _SliderTile(
        label: 'Max Iterations',
        value: state.agentMaxIterations.toDouble(),
        min: 1,
        max: 20,
        divisions: 19,
        displayValue: '${state.agentMaxIterations}',
        onChanged: (v) => ref
            .read(settingsProvider.notifier)
            .updateAgentMaxIterations(v.round()),
      ),
    );
  }
}

class _AppInfoSection extends StatefulWidget {
  @override
  State<_AppInfoSection> createState() => _AppInfoSectionState();
}

class _AppInfoSectionState extends State<_AppInfoSection> {
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
    return _SectionCard(
      title: 'App Info',
      icon: Icons.info_outline,
      child: Column(
        children: [
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Version',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            trailing: Text(
              _version.isNotEmpty ? _version : 'Loading...',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                context.push('/update');
              },
              icon: const Icon(Icons.system_update, size: 18),
              label: const Text('Check for Updates'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'About',
      icon: Icons.code,
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: const Text(
          'GitHub',
          style: TextStyle(color: AppColors.textPrimary),
        ),
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
          borderRadius: BorderRadius.circular(12),
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
                      fontSize: 16,
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

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.displayValue,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String displayValue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
              Text(
                displayValue,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.sliderActive,
              inactiveTrackColor: AppColors.sliderInactive,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.12),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 8);
  }
}

Future<void> _requestStoragePermission(BuildContext context) async {
  final status = await Permission.manageExternalStorage.status;
  if (status.isGranted) return;

  final result = await Permission.manageExternalStorage.request();
  if (result.isPermanentlyDenied && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Storage permission denied. '
          'Enable in Settings > Apps > AIOS > Permissions.',
        ),
      ),
    );
    await openAppSettings();
  }
}
