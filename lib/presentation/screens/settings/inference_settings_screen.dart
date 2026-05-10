import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/core/theme/app_strings.dart';
import 'package:aios/domain/repositories/settings_repository.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/widgets/section_card.dart';
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
        title: Text(Strings.inference.title),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          SectionCard(
            icon: Icons.tune,
            title: Strings.inference.sampling,
            child: Column(
              children: [
                _SliderTile(
                  label: Strings.inference.temperature,
                  description: Strings.inference.temperatureDesc,
                  value: state.temperature,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  defaultValue: SettingsRepository.defaultTemperature,
                  displayValue: state.temperature.toStringAsFixed(2),
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).updateTemperature(v),
                ),
                _SliderTile(
                  label: Strings.inference.topP,
                  description: Strings.inference.topPDesc,
                  value: state.topP,
                  min: 0.01,
                  max: 1,
                  divisions: 20,
                  defaultValue: SettingsRepository.defaultTopP,
                  displayValue: state.topP.toStringAsFixed(2),
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).updateTopP(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SectionCard(
            icon: Icons.memory,
            title: Strings.inference.output,
            child: Column(
              children: [
                _SliderTile(
                  label: Strings.inference.maxTokens,
                  description: Strings.inference.maxTokensDesc,
                  value: state.maxTokens.toDouble(),
                  min: 64,
                  max: 4096,
                  divisions: 30,
                  defaultValue: SettingsRepository.defaultMaxTokens.toDouble(),
                  displayValue: '${state.maxTokens}',
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .updateMaxTokens(v.round()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SectionCard(
            icon: Icons.smart_toy,
            title: Strings.inference.agent,
            child: Column(
              children: [
                _SliderTile(
                  label: Strings.inference.maxIterations,
                  description: Strings.inference.maxIterationsDesc,
                  value: state.agentMaxIterations.toDouble(),
                  min: 1,
                  max: 20,
                  divisions: 19,
                  defaultValue: SettingsRepository.defaultAgentMaxIterations
                      .toDouble(),
                  displayValue: '${state.agentMaxIterations}',
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .updateAgentMaxIterations(v.round()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Semantics(
              label: 'inference_reset_defaults_button',
              button: true,
              child: OutlinedButton.icon(
                onPressed: () => _resetDefaults(ref),
                icon: const Icon(Icons.restore, size: 18),
                label: Text(Strings.inference.resetDefaults),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _resetDefaults(WidgetRef ref) {
    final notifier = ref.read(settingsProvider.notifier);
    notifier
      ..updateTemperature(SettingsRepository.defaultTemperature)
      ..updateTopP(SettingsRepository.defaultTopP)
      ..updateMaxTokens(SettingsRepository.defaultMaxTokens)
      ..updateAgentMaxIterations(SettingsRepository.defaultAgentMaxIterations);
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
                        child: const Icon(
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
            hintText: '${Strings.inference.enterValue} ($min - $max)',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(Strings.chat.cancel),
          ),
          TextButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text);
              if (parsed != null && parsed >= min && parsed <= max) {
                onChanged(parsed);
                Navigator.of(dialogContext).pop();
              }
            },
            child: Text(Strings.inference.apply),
          ),
        ],
      ),
    );
  }
}
