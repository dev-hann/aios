import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/domain/entities/model_info.dart';
import 'package:flutter/material.dart';

class ModelPicker extends StatelessWidget {
  const ModelPicker({
    required this.models,
    required this.onModelSelected,
    required this.onImport,
    this.isLoading = false,
    super.key,
  });

  final List<ModelInfo> models;
  final ValueChanged<ModelInfo> onModelSelected;
  final VoidCallback onImport;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(color: AppColors.primary),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: models.length,
            itemBuilder: (context, index) {
              final model = models[index];
              return ListTile(
                title: Text(
                  model.name,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                subtitle: Text(
                  _formatSize(model.size),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                trailing: const Icon(
                  Icons.download_done,
                  color: AppColors.ready,
                ),
                onTap: () => onModelSelected(model),
              );
            },
          ),
        const Divider(color: Colors.white10),
        ListTile(
          leading: const Icon(Icons.add, color: AppColors.primary),
          title: const Text(
            'Import Model',
            style: TextStyle(color: AppColors.primary),
          ),
          onTap: onImport,
        ),
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  }
}
