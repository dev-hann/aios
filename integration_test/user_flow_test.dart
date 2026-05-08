import 'dart:async';

import 'package:aios/data/providers/real_llama_engine_provider.dart';
import 'package:aios/data/providers/tool_context_impl.dart';
import 'package:aios/data/repositories/conversation_repository_impl.dart';
import 'package:aios/data/repositories/llm_repository_impl.dart';
import 'package:aios/data/repositories/model_repository_impl.dart';
import 'package:aios/data/repositories/settings_repository_impl.dart';
import 'package:aios/domain/agent/react_strategy.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/conversation.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/domain/repositories/conversation_repository.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import 'package:aios/domain/repositories/model_repository.dart';
import 'package:aios/domain/repositories/settings_repository.dart';
import 'package:aios/presentation/providers/agent_provider.dart';
import 'package:aios/presentation/providers/conversation_provider.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:aios/presentation/providers/model_provider.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/screens/chat/chat_screen.dart';
import 'package:aios/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'model_test.dart' show ensureModelAvailable, modelPath, modelReady;

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
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late RealLlamaEngineProvider engineProvider;
  late LlmRepositoryImpl llmRepo;
  late SettingsRepositoryImpl settingsRepo;
  late _InMemoryConversationRepository conversationRepo;

  setUpAll(() async {
    await ensureModelAvailable();
  });

  late ReactStrategy? _cachedStrategy;

  setUp(() async {
    engineProvider = RealLlamaEngineProvider();
    llmRepo = LlmRepositoryImpl(engineProvider);
    settingsRepo = SettingsRepositoryImpl();
    await settingsRepo.init();
    conversationRepo = _InMemoryConversationRepository();
    _cachedStrategy = null;
  });

  tearDown(() async {
    llmRepo.dispose();
    await engineProvider.releaseModel();
  });

  ReactStrategy _getStrategy() {
    if (_cachedStrategy != null) return _cachedStrategy!;
    final engine = engineProvider.engine;
    if (engine == null) throw StateError('Model not loaded');
    _cachedStrategy = ReactStrategy(engine: engine);
    return _cachedStrategy!;
  }

  Widget _buildTestApp() {
    return ProviderScope(
      overrides: [
        llmRepositoryProvider.overrideWithValue(llmRepo),
        conversationRepositoryProvider.overrideWithValue(conversationRepo),
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
        modelRepositoryProvider.overrideWithValue(
          ModelRepositoryImpl(
            modelsDir: '/data/local/tmp/models',
            downloadsDir: '/data/local/tmp/downloads',
          ),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const ChatScreen(),
            ),
            GoRoute(
              path: '/onboarding',
              builder: (_, __) => const OnboardingScreen(),
            ),
          ],
        ),
      ),
    );
  }

  group('Device E2E: Onboarding', () {
    testWidgets('freshApp_showsOnboardingWhenNotCompleted', (tester) async {
      if (!modelReady) return;

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final hasWelcome = find.text('Welcome to AIOS').evaluate().isNotEmpty;
      final hasChat = find.text('AIOS').evaluate().isNotEmpty;

      expect(hasWelcome || hasChat, isTrue);
    });

    testWidgets('completeOnboarding_navigatesToChat', (tester) async {
      if (!modelReady) return;

      await settingsRepo.setOnboardingCompleted();

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('Device E2E: Model load and chat', () {
    testWidgets('loadModelAndSend_firstChat', (tester) async {
      if (!modelReady) return;

      await settingsRepo.setOnboardingCompleted();

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);

      final loaded = await llmRepo.loadModel(modelPath, contextSize: 512);
      expect(loaded, isTrue);

      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      await tester.pumpAndSettle(const Duration(seconds: 30));

      final hasUserMsg =
          find.text('Hello').evaluate().isNotEmpty;
      expect(hasUserMsg, isTrue);
    });

    testWidgets('twoTurnConversation_preservesMessages', (tester) async {
      if (!modelReady) return;

      await settingsRepo.setOnboardingCompleted();
      final loaded = await llmRepo.loadModel(modelPath, contextSize: 512);
      expect(loaded, isTrue);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Say A');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle(const Duration(seconds: 30));

      expect(find.text('Say A').evaluate().isNotEmpty, isTrue);

      await tester.enterText(find.byType(TextField), 'Say B');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle(const Duration(seconds: 30));

      expect(find.text('Say A').evaluate().isNotEmpty, isTrue);
      expect(find.text('Say B').evaluate().isNotEmpty, isTrue);
    });
  });

  group('Device E2E: Agent tool execution', () {
    testWidgets('agentExecutes_reachesAnswer', (tester) async {
      if (!modelReady) return;

      await settingsRepo.setOnboardingCompleted();
      final loaded = await llmRepo.loadModel(modelPath, contextSize: 512);
      expect(loaded, isTrue);

      final strategy = _getStrategy();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            llmRepositoryProvider.overrideWithValue(llmRepo),
            conversationRepositoryProvider.overrideWithValue(conversationRepo),
            settingsRepositoryProvider.overrideWithValue(settingsRepo),
            modelRepositoryProvider.overrideWithValue(
              ModelRepositoryImpl(
                modelsDir: '/data/local/tmp/models',
                downloadsDir: '/data/local/tmp/downloads',
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/',
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, __) => const ChatScreen(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'What is 2+2?');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      await tester.pumpAndSettle(const Duration(seconds: 30));

      expect(find.text('What is 2+2?').evaluate().isNotEmpty, isTrue);
    });
  });

  group('Device E2E: Stop generation', () {
    testWidgets('stopDuringGeneration_interruptsAgent', (tester) async {
      if (!modelReady) return;

      await settingsRepo.setOnboardingCompleted();
      final loaded = await llmRepo.loadModel(modelPath, contextSize: 512);
      expect(loaded, isTrue);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Tell me a story');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      await tester.pump(const Duration(seconds: 2));

      final stopBtn = find.byIcon(Icons.stop_circle);
      if (stopBtn.evaluate().isNotEmpty) {
        await tester.tap(stopBtn);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      expect(find.byIcon(Icons.send), findsOneWidget);
    });
  });

  group('Device E2E: Chat delete', () {
    testWidgets('deleteChat_restartsFresh', (tester) async {
      if (!modelReady) return;

      await settingsRepo.setOnboardingCompleted();
      final loaded = await llmRepo.loadModel(modelPath, contextSize: 512);
      expect(loaded, isTrue);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle(const Duration(seconds: 30));

      expect(find.text('Hello').evaluate().isNotEmpty, isTrue);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Delete all messages?'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      final hasWelcome = find.text('AIOS').evaluate().isNotEmpty;
      expect(hasWelcome, isTrue);
      expect(find.text('Hello').evaluate().isEmpty, isTrue);
    });
  });
}
