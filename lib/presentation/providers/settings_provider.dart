import 'package:aios/domain/repositories/settings_repository.dart';
import 'package:aios/presentation/providers/agent_provider.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:aios/presentation/providers/settings_notifier.dart';
import 'package:aios/presentation/providers/settings_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  throw UnimplementedError('settingsRepositoryProvider must be overridden');
});

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    final settingsRepo = ref.watch(settingsRepositoryProvider);
    final llmRepo = ref.watch(llmRepositoryProvider);
    return SettingsNotifier(
      settingsRepo,
      llmRepo,
      onProviderConnected: (config) {
        ref.read(providerConfigProvider.notifier).state = config;
      },
    );
  },
);
