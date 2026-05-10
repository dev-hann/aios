import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MockLlmRepository implements LlmRepository {
  @override
  Stream<ServiceState> get state => const Stream.empty();

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
}

void main() {
  group('llmRepositoryProvider', () {
    test('llmRepositoryProvider_providesLlmRepositoryInstance', () {
      final mock = MockLlmRepository();
      final container = ProviderContainer(
        overrides: [llmRepositoryProvider.overrideWithValue(mock)],
      );

      final repository = container.read(llmRepositoryProvider);

      expect(repository, isA<LlmRepository>());

      container.dispose();
    });

    test('llmRepositoryProvider_multipleReads_returnsSameInstance', () {
      final mock = MockLlmRepository();
      final container = ProviderContainer(
        overrides: [llmRepositoryProvider.overrideWithValue(mock)],
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
