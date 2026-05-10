import 'package:aios/core/theme/app_strings.dart';
import 'package:aios/domain/agent/agent_strategy.dart';
import 'package:aios/domain/agent/conversation_context.dart';
import 'package:aios/domain/agent/tool_preference_tracker.dart';
import 'package:aios/domain/entities/agent_models.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/conversation.dart';
import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/domain/repositories/conversation_repository.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import 'package:aios/domain/repositories/settings_repository.dart';
import 'package:aios/presentation/providers/agent_provider.dart';
import 'package:aios/presentation/providers/conversation_provider.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/widgets/session_drawer.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubAgent implements AgentStrategy {
  @override
  Future<AgentResult> execute(
    String prompt, {
    int maxIterations = 8,
    int maxTokens = 512,
    void Function(AgentStep)? onStep,
  }) async {
    return AgentResult(steps: [], success: true);
  }

  @override
  void cancel() {}

  @override
  void resolveConfirmation(bool approved) {}

  @override
  void resolvePermission(bool granted) {}

  @override
  void setPermissionChecker(
    Future<bool> Function(String permissionKey)? checker,
  ) {}

  @override
  String getToolManifest() => '';

  @override
  List<({String role, String content})> getConversationHistory() => [];

  @override
  void clearHistory() {}

  @override
  Future<void> warmup() async {}

  @override
  void setConversationContext(ConversationContext? context) {}

  @override
  void setToolPreferenceTracker(ToolPreferenceTracker? tracker) {}
}

class _StubConvRepo implements ConversationRepository {
  @override
  Stream<List<Conversation>> watchAllConversations() => const Stream.empty();

  @override
  Future<List<Conversation>> getAllConversations() async => [];

  @override
  Future<void> save(List<ChatMessage> messages) async {}

  @override
  Future<List<ChatMessage>> load() async => [];

  @override
  Future<void> clear() async {}

  @override
  Future<void> appendMessage(ChatMessage message) async {}

  @override
  Future<Conversation> createConversation({String? title}) async =>
      Conversation(id: 'new', title: title ?? '새 대화');

  @override
  Future<List<ChatMessage>> loadConversation(String id) async => [];

  @override
  Future<void> deleteConversation(String id) async {}

  @override
  Future<void> updateConversationTitle(String id, String title) async {}

  @override
  void setActiveConversationId(String id) {}
}

class _StubLlmRepo implements LlmRepository {
  final _c = StreamController<ServiceState>.broadcast(sync: true);
  @override
  Stream<ServiceState> get state => _c.stream;
  @override
  Future<bool> connect(LlmProviderConfig config) async => true;
  @override
  Future<void> disconnect() async {}
  @override
  bool get isConnected => false;
  @override
  Future<List<LlmModelInfo>> fetchModels(LlmProviderConfig config) async => [];
  @override
  Future<bool> testConnection(LlmProviderConfig config) async => true;
  @override
  Future<void> stopGeneration() async {}
  @override
  Future<void> loadModel(String path, {int? contextSize}) async {}
  void dispose() => _c.close();
}

class _StubSettingsRepo implements SettingsRepository {
  @override
  int get maxTokens => SettingsRepository.defaultMaxTokens;
  @override
  double get temperature => SettingsRepository.defaultTemperature;
  @override
  double get topP => SettingsRepository.defaultTopP;
  @override
  int get agentMaxIterations => SettingsRepository.defaultAgentMaxIterations;
  @override
  String? get providerConfig => null;
  @override
  bool get onboardingCompleted => true;
  @override
  Future<void> setMaxTokens(int value) async {}
  @override
  Future<void> setTemperature(double value) async {}
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionDrawer', () {
    _StubLlmRepo? llmRepo;

    Widget buildWidget() {
      llmRepo = _StubLlmRepo();

      return ProviderScope(
        overrides: [
          llmRepositoryProvider.overrideWithValue(llmRepo!),
          conversationRepositoryProvider.overrideWithValue(_StubConvRepo()),
          settingsRepositoryProvider.overrideWithValue(_StubSettingsRepo()),
          agentProvider.overrideWithValue(_StubAgent()),
        ],
        child: MaterialApp(
          home: Scaffold(body: const SizedBox(), drawer: const SessionDrawer()),
        ),
      );
    }

    tearDown(() {
      llmRepo?.dispose();
    });

    Future<void> openDrawer(WidgetTester tester) async {
      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pump();
    }

    testWidgets('render_displaysAppName', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();
      await openDrawer(tester);

      expect(find.text(Strings.appName), findsOneWidget);
    });

    testWidgets('render_displaysNewChatButton', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();
      await openDrawer(tester);

      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    });

    testWidgets('render_displaysSettingsTile', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();
      await openDrawer(tester);

      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      expect(find.text(Strings.drawer.settings), findsOneWidget);
    });

    testWidgets('render_hasDrawerStructure', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();
      await openDrawer(tester);

      expect(find.byType(Drawer), findsOneWidget);
      expect(find.byType(Divider), findsAtLeast(1));
    });
  });
}
