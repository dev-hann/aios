import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/domain/entities/model_info.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/providers/settings_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

class ModelManagementScreen extends ConsumerWidget {
  const ModelManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final activeModelName = _activeModelName(state);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Model Management'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (state.isLoadingModel)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(color: AppColors.primary),
            ),
          if (activeModelName != null)
            _ActiveModelBanner(name: activeModelName),
          if (state.availableModels.isEmpty)
            _EmptyModelView()
          else
            ...state.availableModels.map(
              (model) => _ModelTile(model: model),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
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
                    onPressed: () => _showImportDialog(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Import'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String? _activeModelName(SettingsState state) {
    if (state.lastModelPath == null) return null;
    final model = state.availableModels
        .where((m) => m.path == state.lastModelPath)
        .firstOrNull;
    return model?.name;
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

class _ActiveModelBanner extends StatelessWidget {
  const _ActiveModelBanner({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        color: AppColors.primary.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.primary),
        ),
        child: ListTile(
          leading: const Icon(Icons.check_circle, color: AppColors.primary),
          title: Text(
            name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: const Text(
            'Active model',
            style: TextStyle(color: AppColors.primary, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

class _EmptyModelView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.psychology_outlined,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          const Text(
            'No models found',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Place .gguf files in the app\'s model directory\nor import from Downloads.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Card(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: isActive ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: ListTile(
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
        ),
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
                      isImported ? Icons.check_circle : Icons.download_rounded,
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
