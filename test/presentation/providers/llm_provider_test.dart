import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MockLlmRepository implements LlmRepository {
  @override
  Stream<ServiceState> get state => const Stream.empty();

  @override
  Stream<String> get tokenStream => const Stream.empty();

  @override
  Stream<double> get loadProgress => const Stream.empty();

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
    String? grammar,
  }) async {}

  @override
  Future<void> stopGeneration() async {}

  @override
  Future<void> saveSession(String path) async {}

  @override
  Future<void> loadSession(String path) async {}
}

void main() {
  group('llmRepositoryProvider', () {
    test('llmRepositoryProvider_providesLlmRepositoryInstance', () {
      final mock = MockLlmRepository();
      final container = ProviderContainer(
        overrides: [
          llmRepositoryProvider.overrideWithValue(mock),
        ],
      );

      final repository = container.read(llmRepositoryProvider);

      expect(repository, isA<LlmRepository>());

      container.dispose();
    });

    test('llmRepositoryProvider_multipleReads_returnsSameInstance', () {
      final mock = MockLlmRepository();
      final container = ProviderContainer(
        overrides: [
          llmRepositoryProvider.overrideWithValue(mock),
        ],
      );

      final first = container.read(llmRepositoryProvider);
      final second = container.read(llmRepositoryProvider);

      expect(identical(first, second), isTrue);

      container.dispose();
    });

    test('llmRepositoryProvider_throwsWhenNotOverridden', () {
      final container = ProviderContainer();

      expect(
        () => container.read(llmRepositoryProvider),
        throwsUnimplementedError,
      );

      container.dispose();
    });
  });
}
