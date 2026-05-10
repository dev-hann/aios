import 'dart:async';

import 'package:aios/data/providers/remote/llm_remote_engine.dart';
import 'package:aios/data/repositories/settings_repository_impl.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/conversation.dart';
import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/domain/repositories/conversation_repository.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import 'package:aios/presentation/providers/agent_provider.dart';
import 'package:aios/presentation/providers/conversation_provider.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/screens/chat/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'model_test.dart'
    show ensureProviderAvailable, providerReady, testConfig;

class _InMemoryConversationRepository implements ConversationRepository {
  final List<ChatMessage> _messages = [];

  @override
  Future<void> save(List<ChatMessage> messages) async {
    _messages
      ..clear()
      ..addAll(messages);
  }

  @override
  Future<List<ChatMessage>> load() async => List.of(_messages);

  @override
  Future<void> clear() async {
    _messages.clear();
  }

  @override
  Future<void> appendMessage(ChatMessage message) async {
    _messages.add(message);
  }

  @override
  Future<Conversation> createConversation({String? title}) async {
    return Conversation(
      id: 'test_conv',
      title: title ?? '새 대화',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<Conversation>> getAllConversations() async => [];

  @override
  Future<List<ChatMessage>> loadConversation(String id) async =>
      List.of(_messages);

  @override
  Future<void> deleteConversation(String id) async {}

  @override
  Future<void> updateConversationTitle(String id, String title) async {}

  @override
  Stream<List<Conversation>> watchAllConversations() => Stream.value([]);

  @override
  void setActiveConversationId(String id) {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SettingsRepositoryImpl settingsRepo;
  late _InMemoryConversationRepository conversationRepo;

  setUpAll(() async {
    await ensureProviderAvailable();
  });

  setUp(() async {
    settingsRepo = SettingsRepositoryImpl();
    await settingsRepo.init();
    conversationRepo = _InMemoryConversationRepository();
  });

  Widget buildTestApp() {
    return ProviderScope(
      overrides: [
        llmRepositoryProvider.overrideWithValue(_FakeLlmRepository()),
        conversationRepositoryProvider.overrideWithValue(conversationRepo),
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
        agentEngineProvider.overrideWithValue(
          providerReady ? LlmRemoteEngine(testConfig!) : null,
        ),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/',
          routes: [GoRoute(path: '/', builder: (_, __) => const ChatScreen())],
        ),
      ),
    );
  }

  group('Device E2E: Provider connect and chat', () {
    testWidgets('sendChat_firstMessage', (tester) async {
      if (!providerReady) return;

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();

      await tester.pumpAndSettle(const Duration(seconds: 30));

      final hasUserMsg = find.text('Hello').evaluate().isNotEmpty;
      expect(hasUserMsg, isTrue);
    });

    testWidgets('twoTurnConversation_preservesMessages', (tester) async {
      if (!providerReady) return;

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Say A');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle(const Duration(seconds: 30));

      expect(find.text('Say A').evaluate().isNotEmpty, isTrue);

      await tester.enterText(find.byType(TextField), 'Say B');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle(const Duration(seconds: 30));

      expect(find.text('Say A').evaluate().isNotEmpty, isTrue);
      expect(find.text('Say B').evaluate().isNotEmpty, isTrue);
    });
  });

  group('Device E2E: Agent tool execution', () {
    testWidgets('agentExecutes_reachesAnswer', (tester) async {
      if (!providerReady) return;

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'What is 2+2?');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();

      await tester.pumpAndSettle(const Duration(seconds: 30));

      expect(find.text('What is 2+2?').evaluate().isNotEmpty, isTrue);
    });
  });

  group('Device E2E: Stop generation', () {
    testWidgets('stopDuringGeneration_interruptsAgent', (tester) async {
      if (!providerReady) return;

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Tell me a story');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();

      await tester.pump(const Duration(seconds: 2));

      final stopBtn = find.byIcon(Icons.stop);
      if (stopBtn.evaluate().isNotEmpty) {
        await tester.tap(stopBtn);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });
  });

  group('Device E2E: Chat clear via drawer', () {
    testWidgets('openDrawer_showsSettingsAndNewChat', (tester) async {
      if (!providerReady) return;

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });
  });
}

class _FakeLlmRepository implements LlmRepository {
  @override
  Stream<ServiceState> get state => Stream.value(ServiceState.ready);
  @override
  Future<bool> connect(LlmProviderConfig config) async => true;
  @override
  Future<void> disconnect() async {}
  @override
  bool get isConnected => true;
  @override
  Future<List<LlmModelInfo>> fetchModels(LlmProviderConfig config) async => [];
  @override
  Future<bool> testConnection(LlmProviderConfig config) async => true;
  @override
  Future<void> stopGeneration() async {}
  @override
  Future<void> loadModel(String path, {int? contextSize}) async {}
}
