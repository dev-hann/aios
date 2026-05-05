import 'dart:async';

import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/model_info.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/domain/repositories/conversation_repository.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import 'package:aios/domain/repositories/model_repository.dart';
import 'package:aios/domain/repositories/settings_repository.dart';
import 'package:aios/presentation/providers/conversation_provider.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:aios/presentation/providers/model_provider.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/providers/settings_state.dart';
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
    int? topK,
    double? topP,
    double? repeatPenalty,
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

class _MockSettingsRepository implements SettingsRepository {
  @override
  int get contextSize => SettingsRepository.defaultContextSize;

  @override
  int get maxTokens => SettingsRepository.defaultMaxTokens;

  @override
  double get temperature => SettingsRepository.defaultTemperature;

  @override
  int get topK => SettingsRepository.defaultTopK;

  @override
  double get topP => SettingsRepository.defaultTopP;

  @override
  double get repeatPenalty => SettingsRepository.defaultRepeatPenalty;

  @override
  int get agentMaxIterations =>
      SettingsRepository.defaultAgentMaxIterations;

  @override
  String? get lastModelPath => null;

  @override
  Future<void> setContextSize(int value) async {}

  @override
  Future<void> setMaxTokens(int value) async {}

  @override
  Future<void> setTemperature(double value) async {}

  @override
  Future<void> setTopK(int value) async {}

  @override
  Future<void> setTopP(double value) async {}

  @override
  Future<void> setRepeatPenalty(double value) async {}

  @override
  Future<void> setAgentMaxIterations(int value) async {}

  @override
  Future<void> setLastModelPath(String path) async {}

  @override
  Future<void> clearLastModelPath() async {}
}

class _MockModelRepository implements ModelRepository {
  @override
  List<ModelInfo> scanModels() => [];

  @override
  List<ModelInfo> scanExternalDirs() => [];

  @override
  bool restoreModel(String name) => false;

  @override
  Future<bool> importModelFromUri(
    String sourcePath,
    String fileName,
  ) async =>
      false;
}

void main() {
  late _MockLlmRepository llmRepo;
  late _MockConversationRepository conversationRepo;

  Widget _buildChatScreen() {
    return ProviderScope(
      overrides: [
        llmRepositoryProvider.overrideWithValue(llmRepo),
        conversationRepositoryProvider
            .overrideWithValue(conversationRepo),
        settingsRepositoryProvider
            .overrideWithValue(_MockSettingsRepository()),
        modelRepositoryProvider
            .overrideWithValue(_MockModelRepository()),
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
}
