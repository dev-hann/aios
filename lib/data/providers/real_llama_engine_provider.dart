import 'dart:async';
import 'dart:developer' as developer;

import 'package:aios/data/providers/llama_engine_provider.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart'
    hide ChatMessage;

class RealLlamaEngineProvider implements LlamaEngineProvider {
  LlamaEngine? _engine;
  EngineChat? _chat;
  StreamSubscription<GenerationEvent>? _activeSub;
  StreamController<String>? _activeController;
  bool _stopRequested = false;

  static const _tag = 'AIOS-RealEngine';

  @override
  Future<bool> loadModel(String path, {int? contextSize}) async {
    try {
      await releaseModel();

      _engine = await LlamaEngine.spawn(
        libraryPath: 'libllama.so',
        modelParams: ModelParams(path: path),
        contextParams: ContextParams(nCtx: contextSize ?? 2048),
      );

      _chat = await _engine!.createChat();

      developer.log(
        'Model loaded: $path (ctx=${contextSize ?? 2048})',
        name: _tag,
      );
      return true;
    } on Object catch (e, st) {
      developer.log(
        'loadModel failed: $e\n$st',
        name: _tag,
        level: 1000,
      );
      _engine = null;
      _chat = null;
      return false;
    }
  }

  @override
  Future<void> releaseModel() async {
    await _activeSub?.cancel();
    _activeSub = null;
    if (_activeController != null && !_activeController!.isClosed) {
      await _activeController!.close();
    }
    _activeController = null;
    _chat = null;
    if (_engine != null) {
      await _engine!.dispose();
      _engine = null;
      developer.log('Model released', name: _tag);
    }
  }

  @override
  bool get isModelLoaded => _engine != null && _chat != null;

  @override
  String getModelInfo() {
    if (_engine == null) return 'No model loaded';
    return 'Engine active (accelerator: ${_engine!.primaryAcceleratorName ?? 'CPU'})';
  }

  @override
  String getContextUsage() {
    if (_chat == null) return '0/0 tokens';
    return '${_chat!.messageCount} messages';
  }

  @override
  Stream<String> generate(
    List<ChatMessage> history,
    String userMessage, {
    double? temperature,
    int? maxTokens,
  }) {
    _stopRequested = false;
    final controller = StreamController<String>();
    _activeController = controller;

    _doGenerate(
      history,
      userMessage,
      temperature: temperature,
      maxTokens: maxTokens,
      controller: controller,
    ).catchError((Object e) {
      developer.log('generate error', name: _tag, error: e, level: 1000);
      if (!controller.isClosed) {
        controller.addError(e);
        controller.close();
      }
    });

    return controller.stream;
  }

  Future<void> _doGenerate(
    List<ChatMessage> history,
    String userMessage, {
    double? temperature,
    int? maxTokens,
    required StreamController<String> controller,
  }) async {
    if (_chat == null) {
      controller.add('Error: No model loaded');
      await controller.close();
      return;
    }

    final chat = _chat!;
    chat.clearHistory();

    for (final msg in history) {
      switch (msg.role) {
        case 'system':
          chat.addSystem(msg.content);
        case 'user':
          chat.addUser(msg.content);
        case 'assistant':
          chat.addAssistant(msg.content);
      }
    }
    chat.addUser(userMessage);

    final sampler = SamplerParams(
      temperature: temperature ?? 0.8,
      topK: 40,
      topP: 0.95,
    );

    final eventStream = chat.generate(
      sampler: sampler,
      maxTokens: maxTokens ?? 512,
    );

    await for (final event in eventStream) {
      if (_stopRequested || controller.isClosed) break;
      switch (event) {
        case TokenEvent():
          controller.add(event.text);
        case DoneEvent():
          break;
        case ShiftEvent():
          break;
      }
    }

    if (!controller.isClosed) {
      await controller.close();
    }
  }

  @override
  Future<void> stopGeneration() async {
    _stopRequested = true;
    await _activeSub?.cancel();
    _activeSub = null;
    if (_activeController != null && !_activeController!.isClosed) {
      await _activeController!.close();
    }
    _activeController = null;
  }

  @override
  Future<void> saveState(String path) async {
    await _chat?.saveState(path);
    developer.log('Session saved: $path', name: _tag);
  }

  @override
  Future<void> loadState(String path) async {
    await _chat?.loadState(path);
    developer.log('Session loaded: $path', name: _tag);
  }
}
