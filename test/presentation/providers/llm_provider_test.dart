import 'package:aios/data/datasources/local/database.dart';
import 'package:aios/data/providers/llama_engine_provider.dart';
import 'package:aios/data/repositories/llm_repository_impl.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import 'package:aios/presentation/providers/database_provider.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MockLlamaEngineProvider implements LlamaEngineProvider {
  @override
  Future<bool> loadModel(String path, {int? contextSize}) async => true;

  @override
  Future<void> releaseModel() async {}

  @override
  bool get isModelLoaded => false;

  @override
  String getModelInfo() => 'MockModel';

  @override
  String getContextUsage() => '0/2048';

  @override
  Stream<String> generate(
    List<ChatMessage> history,
    String userMessage, {
    double? temperature,
    int? maxTokens,
  }) =>
      const Stream.empty();

  @override
  Future<void> stopGeneration() async {}

  @override
  Future<void> saveState(String path) async {}

  @override
  Future<void> loadState(String path) async {}
}

void main() {
  group('llmRepositoryProvider', () {
    test('shouldProvideLlmRepositoryInstance', () {
      final container = ProviderContainer(
        overrides: [
          llamaEngineProvider
              .overrideWithValue(MockLlamaEngineProvider()),
        ],
      );

      final repository = container.read(llmRepositoryProvider);

      expect(repository, isA<LlmRepository>());
      expect(repository, isA<LlmRepositoryImpl>());

      container.dispose();
    });

    test('shouldProvideSameInstanceOnMultipleReads', () {
      final container = ProviderContainer(
        overrides: [
          llamaEngineProvider
              .overrideWithValue(MockLlamaEngineProvider()),
        ],
      );

      final first = container.read(llmRepositoryProvider);
      final second = container.read(llmRepositoryProvider);

      expect(identical(first, second), isTrue);

      container.dispose();
    });
  });

  group('llamaEngineProvider', () {
    test('shouldBeOverridable', () {
      final mock = MockLlamaEngineProvider();
      final container = ProviderContainer(
        overrides: [
          llamaEngineProvider.overrideWithValue(mock),
        ],
      );

      final engine = container.read(llamaEngineProvider);
      expect(engine, mock);

      container.dispose();
    });
  });

  group('appDatabaseProvider', () {
    test('shouldProvideAppDatabaseInstance', () {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(
            AppDatabase.forTesting(NativeDatabase.memory()),
          ),
        ],
      );

      final db = container.read(appDatabaseProvider);
      expect(db, isA<AppDatabase>());

      container.dispose();
    });

    test('shouldProvideSameInstanceOnMultipleReads', () {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(
            AppDatabase.forTesting(NativeDatabase.memory()),
          ),
        ],
      );

      final first = container.read(appDatabaseProvider);
      final second = container.read(appDatabaseProvider);
      expect(identical(first, second), isTrue);

      container.dispose();
    });
  });
}
