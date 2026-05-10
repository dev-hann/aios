import 'dart:async';

import 'package:aios/domain/agent/agent_strategy.dart';
import 'package:aios/domain/agent/conversation_context.dart';
import 'package:aios/domain/agent/tool_preference_tracker.dart';
import 'package:aios/domain/entities/agent_models.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/conversation.dart';
import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/domain/entities/update_info.dart';
import 'package:aios/domain/repositories/conversation_repository.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import 'package:aios/domain/repositories/settings_repository.dart';
import 'package:aios/domain/repositories/update_repository.dart';
import 'package:aios/presentation/providers/agent_provider.dart';
import 'package:aios/presentation/providers/conversation_provider.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/providers/update_provider.dart';
import 'package:aios/presentation/screens/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockSettingsRepository implements SettingsRepository {
  @override
  double get temperature => SettingsRepository.defaultTemperature;
  @override
  int get maxTokens => SettingsRepository.defaultMaxTokens;
  @override
  double get topP => SettingsRepository.defaultTopP;
  @override
  int get agentMaxIterations => SettingsRepository.defaultAgentMaxIterations;
  @override
  String? get providerConfig => null;
  @override
  bool get onboardingCompleted => true;
  @override
  Future<void> setTemperature(double value) async {}
  @override
  Future<void> setMaxTokens(int value) async {}
  @override
  Future<void> setTopP(double value) async {}
  @override
  Future<void> setAgentMaxIterations(int value) async {}
  @override
  Future<void> setProviderConfig(String json) async {}
  @override
  Future<void> clearProviderConfig() async {}
  @override
  Future<void> setOnboardingCompleted() async {}
}

class _MockUpdateRepository implements UpdateRepository {
  @override
  Future<UpdateResult> checkForUpdate() async =>
      const UpdateResult.notAvailable();
  @override
  Future<String?> downloadApk(
    String url,
    String fileName, {
    void Function(double progress)? onProgress,
  }) async => null;
  @override
  Future<bool> installApk(String apkPath) async => false;
}

class _MockLlmRepository implements LlmRepository {
  final _stateController = StreamController<ServiceState>.broadcast();

  @override
  Stream<ServiceState> get state => _stateController.stream;

  @override
  Future<bool> connect(LlmProviderConfig config) async => true;

  @override
  Future<void> disconnect() async {}

  @override
  bool get isConnected => false;

  @override
  Future<List<LlmModelInfo>> fetchModels(LlmProviderConfig config) async {
    return [];
  }

  @override
  Future<bool> testConnection(LlmProviderConfig config) async => true;

  @override
  Future<void> stopGeneration() async {}

  @override
  Future<void> loadModel(String path, {int? contextSize}) async {}

  void dispose() {
    _stateController.close();
  }
}

class _MockConversationRepository implements ConversationRepository {
  @override
  Future<void> save(List<ChatMessage> messages) async {}
  @override
  Future<List<ChatMessage>> load() async => [];
  @override
  Future<void> clear() async {}
  @override
  Future<void> appendMessage(ChatMessage message) async {}
  @override
  Future<Conversation> createConversation({String? title}) async {
    return Conversation(
      id: 'test_conv',
      title: title ?? 'Test',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<Conversation>> getAllConversations() async => [];
  @override
  Future<List<ChatMessage>> loadConversation(String id) async => [];
  @override
  Future<void> deleteConversation(String id) async {}
  @override
  Future<void> updateConversationTitle(String id, String title) async {}
  @override
  Stream<List<Conversation>> watchAllConversations() => Stream.value([]);
  @override
  void setActiveConversationId(String id) {}
}

class _NoOpAgent implements AgentStrategy {
  @override
  Future<AgentResult> execute(
    String prompt, {
    int maxIterations = 8,
    int maxTokens = 512,
    void Function(AgentStep)? onStep,
  }) async {
    return AgentResult(steps: [const AgentStep('answer', 'ok')], success: true);
  }

  @override
  Future<void> warmup() async {}
  @override
  void cancel() {}
  @override
  void resolveConfirmation(bool approved) {}
  @override
  void clearHistory() {}
  @override
  String getToolManifest() => '';
  @override
  List<({String role, String content})> getConversationHistory() => [];
  @override
  void setConversationContext(ConversationContext? context) {}
  @override
  void setToolPreferenceTracker(ToolPreferenceTracker? tracker) {}
  @override
  void resolvePermission(bool granted) {}
  @override
  void setPermissionChecker(
    Future<bool> Function(String permissionKey)? checker,
  ) {}
}

void main() {
  late _MockLlmRepository llmRepo;

  Widget _buildApp() {
    return ProviderScope(
      overrides: [
        llmRepositoryProvider.overrideWithValue(llmRepo),
        conversationRepositoryProvider.overrideWithValue(
          _MockConversationRepository(),
        ),
        settingsRepositoryProvider.overrideWithValue(_MockSettingsRepository()),
        agentProvider.overrideWithValue(_NoOpAgent()),
        updateRepositoryProvider.overrideWithValue(_MockUpdateRepository()),
        currentVersionProvider.overrideWithValue('1.0.0'),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    );
  }

  setUp(() {
    llmRepo = _MockLlmRepository();
  });

  tearDown(() {
    llmRepo.dispose();
  });

  group('SettingsScreen semantics', () {
    testWidgets('render_displaysSettingsTitle', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.text('설정'), findsOneWidget);
    });

    testWidgets('render_hasInferenceTile', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('settings_inference_tile'), findsOneWidget);
    });

    testWidgets('render_hasPermissionsTile', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('settings_permissions_tile'),
        findsOneWidget,
      );
    });
  });
}
