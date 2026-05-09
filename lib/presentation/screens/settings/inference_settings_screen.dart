import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/domain/repositories/settings_repository.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InferenceSettingsScreen extends ConsumerWidget {
  const InferenceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Inference Settings'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _ParamCard(
            icon: Icons.tune,
            title: 'Sampling',
            children: [
              _SliderTile(
                label: 'Temperature',
                description: 'Controls randomness',
                value: state.temperature,
                min: 0.0,
                max: 2.0,
                divisions: 20,
                defaultValue: SettingsRepository.defaultTemperature,
                displayValue: state.temperature.toStringAsFixed(2),
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .updateTemperature(v),
              ),
              _SliderTile(
                label: 'Top-K',
                description: 'Limits sampling to top K tokens',
                value: state.topK.toDouble(),
                min: 1,
                max: 100,
                divisions: 99,
                defaultValue: SettingsRepository.defaultTopK.toDouble(),
                displayValue: '${state.topK}',
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).updateTopK(v.round()),
              ),
              _SliderTile(
                label: 'Top-P',
                description: 'Nucleus sampling threshold',
                value: state.topP,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                defaultValue: SettingsRepository.defaultTopP,
                displayValue: state.topP.toStringAsFixed(2),
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).updateTopP(v),
              ),
              _SliderTile(
                label: 'Repeat Penalty',
                description: 'Penalizes repeated tokens',
                value: state.repeatPenalty,
                min: 0.5,
                max: 2.0,
                divisions: 15,
                defaultValue: SettingsRepository.defaultRepeatPenalty,
                displayValue: state.repeatPenalty.toStringAsFixed(2),
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .updateRepeatPenalty(v),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ParamCard(
            icon: Icons.memory,
            title: 'Context & Output',
            children: [
              _SliderTile(
                label: 'Context Size',
                description: 'Max input tokens the model can process',
                value: state.contextSize.toDouble(),
                min: 512,
                max: 8192,
                divisions: 15,
                defaultValue: SettingsRepository.defaultContextSize.toDouble(),
                displayValue: '${state.contextSize}',
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .updateContextSize(v.round()),
              ),
              _SliderTile(
                label: 'Max Tokens',
                description: 'Max output tokens per response',
                value: state.maxTokens.toDouble(),
                min: 64,
                max: 2048,
                divisions: 18,
                defaultValue: SettingsRepository.defaultMaxTokens.toDouble(),
                displayValue: '${state.maxTokens}',
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .updateMaxTokens(v.round()),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ParamCard(
            icon: Icons.smart_toy,
            title: 'Agent',
            children: [
              _SliderTile(
                label: 'Max Iterations',
                description: 'Max agent reasoning loops',
                value: state.agentMaxIterations.toDouble(),
                min: 1,
                max: 20,
                divisions: 19,
                defaultValue:
                    SettingsRepository.defaultAgentMaxIterations.toDouble(),
                displayValue: '${state.agentMaxIterations}',
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .updateAgentMaxIterations(v.round()),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => _resetDefaults(ref),
              icon: const Icon(Icons.restore, size: 18),
              label: const Text('Reset to Defaults'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _resetDefaults(WidgetRef ref) {
    final notifier = ref.read(settingsProvider.notifier);
    notifier.updateTemperature(SettingsRepository.defaultTemperature);
    notifier.updateTopK(SettingsRepository.defaultTopK);
    notifier.updateTopP(SettingsRepository.defaultTopP);
    notifier.updateRepeatPenalty(SettingsRepository.defaultRepeatPenalty);
    notifier.updateContextSize(SettingsRepository.defaultContextSize);
    notifier.updateMaxTokens(SettingsRepository.defaultMaxTokens);
    notifier.updateAgentMaxIterations(SettingsRepository.defaultAgentMaxIterations);
  }
}

class _ParamCard extends StatelessWidget {
  const _ParamCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

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
              ...children,
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
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.defaultValue,
    required this.displayValue,
    required this.onChanged,
  });

  final String label;
  final String description;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final double defaultValue;
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showEditDialog(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayValue,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((value - defaultValue).abs() > 0.001) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => onChanged(defaultValue),
                        child: Icon(
                          Icons.refresh,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
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

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: displayValue);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          label,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter value ($min - $max)',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text);
              if (parsed != null && parsed >= min && parsed <= max) {
                onChanged(parsed);
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
