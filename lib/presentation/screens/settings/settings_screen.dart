import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/domain/entities/model_info.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/providers/settings_state.dart';
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
                      ref.read(settingsProvider.notifier).scanModels();
                    }
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Scan'),
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
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) async {
    final externalModels =
        ref.read(settingsProvider.notifier).scanImportableModels();
    final internalModels = ref.read(settingsProvider).availableModels;
    final internalNames = internalModels.map((m) => m.name).toSet();

    if (!context.mounted) return;

    if (externalModels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No .gguf files found in Downloads folder'),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => _ImportDialog(
        models: externalModels,
        internalNames: internalNames,
        onImport: (model) async {
          final success = await ref
              .read(settingsProvider.notifier)
              .importModel(model.path, model.name);
          if (dialogContext.mounted) {
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              SnackBar(
                content: Text(
                  success
                      ? 'Model imported: ${model.name}'
                      : 'Failed to import model',
                ),
              ),
            );
          }
        },
      ),
    );
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
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
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
                ref.read(settingsProvider.notifier).loadModel(model.path);
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

class _ImportDialog extends StatefulWidget {
  const _ImportDialog({
    required this.models,
    required this.internalNames,
    required this.onImport,
  });

  final List<ModelInfo> models;
  final Set<String> internalNames;
  final Future<void> Function(ModelInfo) onImport;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  String? _importingName;
  final Set<String> _importedNames = {};

  @override
  void initState() {
    super.initState();
    _importedNames.addAll(widget.internalNames);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Import Model',
        style: TextStyle(color: AppColors.textPrimary),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.models.isEmpty
            ? const Text(
                'No importable models found',
                style: TextStyle(color: AppColors.textSecondary),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: widget.models.length,
                itemBuilder: (context, index) {
                  final model = widget.models[index];
                  final isImported = _importedNames.contains(model.name);
                  final isImporting = _importingName == model.name;

                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isImported
                          ? Icons.check_circle
                          : Icons.download_rounded,
                      color: isImported
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                    title: Text(
                      model.name,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: isImported
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      _formatSize(model.size),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: isImported
                        ? const Text(
                            'Imported',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          )
                        : isImporting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            : TextButton(
                                onPressed: () => _handleImport(model),
                                child: const Text('Import'),
                              ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _handleImport(ModelInfo model) async {
    setState(() => _importingName = model.name);
    await widget.onImport(model);
    if (mounted) {
      setState(() {
        _importingName = null;
        _importedNames.add(model.name);
      });
    }
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
            title: const Text('Version'),
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
                  fontSize: 13,
                ),
              ),
              Text(
                displayValue,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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
