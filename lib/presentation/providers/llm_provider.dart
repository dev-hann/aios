import 'package:aios/data/providers/llama_engine_provider.dart';
import 'package:aios/domain/repositories/llm_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final llamaEngineProvider = Provider<LlamaEngineProvider>((ref) {
  throw UnimplementedError('llamaEngineProvider must be overridden');
});

final llmRepositoryProvider = Provider<LlmRepository>((ref) {
  throw UnimplementedError('llmRepositoryProvider must be overridden');
});
