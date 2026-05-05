import 'dart:async';

import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/domain/repositories/conversation_repository.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import 'package:aios/presentation/providers/chat_notifier.dart';
import 'package:aios/presentation/providers/chat_providers.dart';
import 'package:aios/presentation/providers/conversation_provider.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:aios/presentation/screens/chat/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockLlmRepository implements LlmRepository {
  final _stateController = StreamController<ServiceState>.broadcast();
  final _tokenController = StreamController<String>.broadcast();
  final _progressController = StreamController<double>.broadcast();

  bool modelLoaded = false;
  List<String> tokens = [];

  @override
  Stream<ServiceState> get state => _stateController.stream;

  @override
  Stream<String> get tokenStream => _tokenController.stream;

  @override
  Stream<double> get loadProgress => _progressController.stream;

  @override
  Future<bool> loadModel(String path, {int? contextSize}) async {
    modelLoaded = true;
    _stateController.add(ServiceState.ready);
    return true;
  }

  @override
  Future<void> releaseModel() async {
    modelLoaded = false;
    _stateController.add(ServiceState.idle);
  }

  @override
  bool get isModelLoaded => modelLoaded;

  @override
  String getModelInfo() => 'MockModel v1.0';

  @override
  String getContextUsage() => '0/2048 tokens';

  @override
  Future<void> resetContext() async {}

  @override
  Future<void> sendMessage(
    List<ChatMessage> history, {
    required String userMessage,
    double? temperature,
    int? maxTokens,
  }) async {
    _stateController.add(ServiceState.generating);
    for (final token in tokens) {
      _tokenController.add(token);
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
    _stateController.add(ServiceState.ready);
  }

  @override
  Future<void> stopGeneration() async {}

  @override
  Future<void> saveSession(String path) async {}

  @override
  Future<void> loadSession(String path) async {}

  void emitState(ServiceState s) => _stateController.add(s);

  void dispose() {
    _stateController.close();
    _tokenController.close();
    _progressController.close();
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
}

void main() {
  late _MockLlmRepository llmRepo;
  late _MockConversationRepository conversationRepo;

  Widget _buildChatScreen() {
    return ProviderScope(
      overrides: [
        llmRepositoryProvider.overrideWithValue(llmRepo),
        conversationRepositoryProvider.overrideWithValue(conversationRepo),
      ],
      child: const MaterialApp(home: ChatScreen()),
    );
  }

  Widget _buildChatScreenWithMessages() {
    return ProviderScope(
      overrides: [
        llmRepositoryProvider.overrideWithValue(llmRepo),
        conversationRepositoryProvider.overrideWithValue(conversationRepo),
        chatStateProvider.overrideWith((ref) {
          final notifier = ChatNotifier(llmRepo, conversationRepo);
          notifier.state = notifier.state.copyWith(
            messages: [
              ChatMessage(
                id: 'msg1',
                role: 'user',
                content: 'Hello',
                createdAt: DateTime.now(),
              ),
            ],
            serviceState: ServiceState.ready,
          );
          return notifier;
        }),
      ],
      child: const MaterialApp(home: ChatScreen()),
    );
  }

  setUp(() {
    llmRepo = _MockLlmRepository();
    conversationRepo = _MockConversationRepository();
  });

  tearDown(() {
    llmRepo.dispose();
  });

  testWidgets('showsWelcome_whenNoMessages', (tester) async {
    await tester.pumpWidget(_buildChatScreen());
    await tester.pump();

    expect(find.text('AIOS'), findsOneWidget);
    expect(find.text('Your on-device AI assistant'), findsOneWidget);
  });

  testWidgets('showsMessages_afterSending', (tester) async {
    llmRepo.tokens = ['Hi'];
    await tester.pumpWidget(_buildChatScreen());
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('showsInputBar', (tester) async {
    await tester.pumpWidget(_buildChatScreen());
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
  });

  testWidgets('showsGeneratingIndicator_whileGenerating', (tester) async {
    llmRepo.tokens = [];
    await tester.pumpWidget(_buildChatScreen());
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.byIcon(Icons.stop_circle), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('showsModelLoadingView', (tester) async {
    await tester.pumpWidget(_buildChatScreen());
    await tester.pump();

    llmRepo.emitState(ServiceState.loadingModel);
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading Model...'), findsAtLeast(1));
  });

  testWidgets('tappingSend_triggersSendMessage', (tester) async {
    llmRepo.tokens = ['Response'];
    await tester.pumpWidget(_buildChatScreen());
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Test message');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Test message'), findsOneWidget);
  });

  testWidgets('showsSettingsIcon', (tester) async {
    await tester.pumpWidget(_buildChatScreen());
    await tester.pump();

    expect(find.byIcon(Icons.settings), findsOneWidget);
  });

  testWidgets('showsErrorState', (tester) async {
    await tester.pumpWidget(_buildChatScreen());
    await tester.pump();

    llmRepo.emitState(ServiceState.error);
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Error'), findsOneWidget);
  });

  testWidgets('hidesDeleteIcon_whenNoMessages', (tester) async {
    await tester.pumpWidget(_buildChatScreen());
    await tester.pump();

    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('showsDeleteIcon_whenMessagesExist', (tester) async {
    await tester.pumpWidget(_buildChatScreenWithMessages());
    await tester.pump();

    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('tapDelete_showsClearChatDialog', (tester) async {
    await tester.pumpWidget(_buildChatScreenWithMessages());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Clear Chat'), findsOneWidget);
    expect(find.text('Delete all messages?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
  });

  testWidgets('tapCancelInDialog_dismissesWithoutClearing',
      (tester) async {
    await tester.pumpWidget(_buildChatScreenWithMessages());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Clear Chat'), findsNothing);
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('tapClearInDialog_clearsMessages', (tester) async {
    await tester.pumpWidget(_buildChatScreenWithMessages());
    await tester.pump();

    expect(find.text('Hello'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Hello'), findsNothing);
    expect(find.text('AIOS'), findsOneWidget);
  });

  testWidgets('showsContextUsage_whenServiceStateReady',
      (tester) async {
    await tester.pumpWidget(_buildChatScreen());
    await tester.pump();

    llmRepo.emitState(ServiceState.ready);
    await tester.pump();
    await tester.pump();

    expect(find.text('0/2048 tokens'), findsOneWidget);
  });

  testWidgets('hidesContextUsage_whenServiceStateNotReady',
      (tester) async {
    await tester.pumpWidget(_buildChatScreen());
    await tester.pump();

    llmRepo.emitState(ServiceState.idle);
    await tester.pump();
    await tester.pump();

    expect(find.text('0/2048 tokens'), findsNothing);
  });
}
