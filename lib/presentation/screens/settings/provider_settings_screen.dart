import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/core/theme/app_strings.dart';
import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProviderSettingsScreen extends ConsumerStatefulWidget {
  const ProviderSettingsScreen({super.key});

  @override
  ConsumerState<ProviderSettingsScreen> createState() =>
      _ProviderSettingsScreenState();
}

class _ProviderSettingsScreenState
    extends ConsumerState<ProviderSettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();
  LlmProviderType _selectedType = LlmProviderType.zai;
  String _selectedModel = '';
  List<LlmModelInfo> _models = [];
  bool _isLoadingModels = false;
  bool _isTesting = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    final config = ref.read(settingsProvider).providerConfig;
    if (config != null) {
      _selectedType = config.type;
      _apiKeyController.text = config.apiKey;
      _baseUrlController.text = config.baseUrl ?? '';
      _selectedModel = config.model;
      _loadModels();
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadModels() async {
    if (_apiKeyController.text.isEmpty) return;
    setState(() => _isLoadingModels = true);

    final config = _buildConfig();
    try {
      final notifier = ref.read(settingsProvider.notifier);
      await notifier.fetchModels(config);
      if (!mounted) return;
      final state = ref.read(settingsProvider);
      setState(() {
        _models = state.availableModels;
        _isLoadingModels = false;
        if (_selectedModel.isEmpty && _models.isNotEmpty) {
          _selectedModel = _models.first.id;
        }
      });
    } on Object catch (e) {
      print('[AIOS-ProviderSettings] ERROR: fetch models - $e');
      if (mounted) {
        setState(() => _isLoadingModels = false);
      }
    }
  }

  LlmProviderConfig _buildConfig() {
    return LlmProviderConfig(
      type: _selectedType,
      apiKey: _apiKeyController.text.trim(),
      model: _selectedModel,
      baseUrl: _baseUrlController.text.trim().isEmpty
          ? null
          : _baseUrlController.text.trim(),
    );
  }

  Future<void> _testConnection() async {
    if (_apiKeyController.text.isEmpty) return;
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final config = _buildConfig();
    final notifier = ref.read(settingsProvider.notifier);
    final ok = await notifier.testConnection(config);

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _testResult = ok
          ? Strings.provider.connectionSuccess
          : Strings.provider.connectionFailed;
    });
  }

  Future<void> _save() async {
    if (_apiKeyController.text.isEmpty || _selectedModel.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(Strings.provider.requiredFields)));
      return;
    }

    final config = _buildConfig();
    final notifier = ref.read(settingsProvider.notifier);
    final ok = await notifier.connect(config);

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(Strings.provider.connectedNotif)));
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(Strings.provider.connectFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(Strings.provider.title),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _ProviderTypeSection(
            selectedType: _selectedType,
            onChanged: (type) {
              setState(() {
                _selectedType = type;
                _selectedModel = '';
                _models = [];
              });
              if (_apiKeyController.text.isNotEmpty) {
                _loadModels();
              }
            },
          ),
          const SizedBox(height: 8),
          _ApiKeySection(
            controller: _apiKeyController,
            onChanged: () {
              if (_apiKeyController.text.isNotEmpty) {
                _loadModels();
              }
            },
          ),
          if (_selectedType == LlmProviderType.custom) ...[
            const SizedBox(height: 8),
            _BaseUrlSection(controller: _baseUrlController),
          ],
          const SizedBox(height: 8),
          _TestConnectionSection(
            isTesting: _isTesting,
            testResult: _testResult,
            onTest: _testConnection,
          ),
          const SizedBox(height: 8),
          _ModelSelectionSection(
            models: _models,
            isLoading: _isLoadingModels,
            selectedModel: _selectedModel,
            onModelSelected: (model) => setState(() => _selectedModel = model),
            onRefresh: _loadModels,
          ),
          const SizedBox(height: 8),
          if (ref.read(settingsProvider).providerConfig != null)
            _DisconnectSection(
              onDisconnect: () {
                ref.read(settingsProvider.notifier).disconnect();
                setState(() {
                  _selectedModel = '';
                  _apiKeyController.clear();
                  _models = [];
                });
              },
            ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: _save,
              child: Text(Strings.provider.saveConnect),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ProviderTypeSection extends StatelessWidget {
  const _ProviderTypeSection({
    required this.selectedType,
    required this.onChanged,
  });

  final LlmProviderType selectedType;
  final ValueChanged<LlmProviderType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: Strings.provider.selectProvider,
      icon: Icons.cloud,
      child: Column(
        children: LlmProviderType.values
            .map(
              (type) => RadioListTile<LlmProviderType>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  Strings.provider.nameForType(type),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                subtitle: _isDisabled(type)
                    ? Text(
                        Strings.provider.comingSoon,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      )
                    : null,
                value: type,
                groupValue: selectedType,
                onChanged: _isDisabled(type) ? null : (v) => onChanged(v!),
                activeColor: AppColors.primary,
              ),
            )
            .toList(),
      ),
    );
  }

  bool _isDisabled(LlmProviderType type) => switch (type) {
    LlmProviderType.zai => false,
    LlmProviderType.zaiCoding => false,
    LlmProviderType.custom => false,
    _ => true,
  };
}

class _ApiKeySection extends StatelessWidget {
  const _ApiKeySection({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: Strings.provider.apiKey,
      icon: Icons.key,
      child: TextField(
        controller: controller,
        obscureText: true,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: Strings.provider.enterApiKey,
          hintStyle: const TextStyle(color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
        ),
        onChanged: (_) => onChanged(),
      ),
    );
  }
}

class _BaseUrlSection extends StatelessWidget {
  const _BaseUrlSection({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: Strings.provider.baseUrl,
      icon: Icons.link,
      child: TextField(
        controller: controller,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'https://api.example.com/v1',
          hintStyle: const TextStyle(color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
        ),
      ),
    );
  }
}

class _TestConnectionSection extends StatelessWidget {
  const _TestConnectionSection({
    required this.isTesting,
    required this.testResult,
    required this.onTest,
  });

  final bool isTesting;
  final String? testResult;
  final VoidCallback onTest;

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
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isTesting ? null : onTest,
                  icon: isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : const Icon(Icons.wifi_find, size: 18),
                  label: Text(
                    isTesting
                        ? Strings.provider.testing
                        : Strings.provider.testConnection,
                  ),
                ),
              ),
              if (testResult != null) ...[
                const SizedBox(height: 8),
                Text(
                  testResult!,
                  style: TextStyle(
                    color: testResult == Strings.provider.connectionSuccess
                        ? AppColors.success
                        : AppColors.error,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelSelectionSection extends StatelessWidget {
  const _ModelSelectionSection({
    required this.models,
    required this.isLoading,
    required this.selectedModel,
    required this.onModelSelected,
    required this.onRefresh,
  });

  final List<LlmModelInfo> models;
  final bool isLoading;
  final String selectedModel;
  final ValueChanged<String> onModelSelected;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: Strings.provider.model,
      icon: Icons.model_training,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SizedBox()),
              IconButton(
                onPressed: isLoading ? null : onRefresh,
                icon: isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(
                        Icons.refresh,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (models.isEmpty && !isLoading)
            Text(
              Strings.provider.enterApiKeyToLoad,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            )
          else
            ...models.map(
              (model) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Radio<String>(
                  value: model.id,
                  groupValue: selectedModel,
                  onChanged: (v) => onModelSelected(v!),
                  activeColor: AppColors.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                title: Text(
                  model.displayName,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: selectedModel == model.id
                        ? FontWeight.w600
                        : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Text(
                      model.id,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...model.capabilities.map(
                      (cap) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          _capabilityIcon(cap),
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                onTap: () => onModelSelected(model.id),
              ),
            ),
        ],
      ),
    );
  }

  IconData _capabilityIcon(ModelCapability cap) => switch (cap) {
    ModelCapability.toolCalling => Icons.build,
    ModelCapability.vision => Icons.visibility,
    ModelCapability.thinking => Icons.psychology,
  };
}

class _DisconnectSection extends StatelessWidget {
  const _DisconnectSection({required this.onDisconnect});

  final VoidCallback onDisconnect;

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
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onDisconnect,
              icon: const Icon(
                Icons.cloud_off,
                size: 18,
                color: AppColors.error,
              ),
              label: Text(
                Strings.provider.disconnect,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
