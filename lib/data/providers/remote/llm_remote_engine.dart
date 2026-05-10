import 'package:aios/data/providers/remote/llm_remote_session.dart';
import 'package:aios/data/providers/remote/openai_client.dart';
import 'package:aios/domain/agent/llm_engine.dart';
import 'package:aios/domain/entities/llm_provider_config.dart';

class LlmRemoteEngine implements LlmEngine {
  LlmRemoteEngine(this._config);

  final LlmProviderConfig _config;
  OpenAiClient? _client;

  static const _tag = 'AIOS-LlmRemoteEngine';

  @override
  LlmChatSession createSession(String systemPrompt) {
    _client = OpenAiClient(_config);
    print('[$_tag] Session created (model=${_config.model})');
    return LlmRemoteSession(client: _client!, systemPrompt: systemPrompt);
  }

  @override
  void cancelGeneration() {
    _client?.cancel();
    print('[$_tag] Generation cancelled');
  }

  @override
  Future<void> warmup() async {
    print('[$_tag] Warmup skipped (remote)');
  }
}
