import '../../helpers/mock_llm_repository.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('llmRepositoryProvider', () {
    test('llmRepositoryProvider_providesLlmRepositoryInstance', () {
      final mock = MockLlmRepository();
      final container = ProviderContainer(
        overrides: [llmRepositoryProvider.overrideWithValue(mock)],
      );

      final repository = container.read(llmRepositoryProvider);

      expect(repository, isA<MockLlmRepository>());

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
