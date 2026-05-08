import 'dart:async';

import 'package:aios/data/providers/llama_engine_provider.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:llamadart/llamadart.dart' hide ChatMessage;

class RealLlamaEngineProvider implements LlamaEngineProvider {
  LlamaEngine? _engine;
  StreamController<String>? _activeController;
  bool _stopRequested = false;
  bool _isGemma4 = false;

  static const _tag = 'AIOS-RealEngine';

  static bool isGemma4Model(String path) {
    final name = path.toLowerCase();
    return name.contains('gemma-4') || name.contains('gemma4');
  }

  static String renderGemma4Prompt(
    List<ChatMessage> history,
    String userMessage,
  ) {
    final buf = StringBuffer();
    final allMessages = <ChatMessage>[
      ...history,
      ChatMessage(
        id: 'user',
        role: 'user',
        content: userMessage,
        createdAt: DateTime.now(),
      ),
    ];
    for (final msg in allMessages) {
      final role = msg.role == 'assistant' ? 'model' : msg.role;
      buf
        ..write('<|turn>')
        ..writeln(role)
        ..write(msg.content)
        ..writeln('<turn|>');
    }
    buf
      ..write('<|turn>')
      ..writeln('model');
    return buf.toString();
  }

  @override
  Future<bool> loadModel(String path, {int? contextSize}) async {
    try {
      await releaseModel();

      _isGemma4 = isGemma4Model(path);

      _engine = LlamaEngine(LlamaBackend());

      try {
        await _engine!.loadModel(
          path,
          modelParams: ModelParams(
            contextSize: contextSize ?? 2048,
            gpuLayers: 99,
          ),
        );
      } on Object catch (e, st) {
        print('[$_tag] ERROR: loadModel internal: $e\n$st');
        _engine = null;
        _isGemma4 = false;
        return false;
      }

      print('[$_tag] Model loaded: $path '
          '(ctx=${contextSize ?? 2048}, '
          'mode=${_isGemma4 ? 'gemma4-raw' : 'chat'})');
      return true;
    } on Object catch (e, st) {
      print('[$_tag] ERROR: loadModel failed: $e\n$st');
      _engine = null;
      _isGemma4 = false;
      return false;
    }
  }

  @override
  Future<void> releaseModel() async {
    if (_activeController != null && !_activeController!.isClosed) {
      await _activeController!.close();
    }
    _activeController = null;
    _isGemma4 = false;
    if (_engine != null) {
      await _engine!.dispose();
      _engine = null;
      print('[$_tag] Model released');
    }
  }

  LlamaEngine? get engine => _engine;

  @override
  bool get isModelLoaded => _engine != null;

  @override
  String getModelInfo() {
    if (_engine == null) return 'No model loaded';
    return 'Engine active (llamadart)';
  }

  @override
  String getContextUsage() {
    if (_engine == null) return '0/0 tokens';
    return 'engine active';
  }

  @override
  Stream<String> generate(
    List<ChatMessage> history,
    String userMessage, {
    double? temperature,
    int? maxTokens,
    int? topK,
    double? topP,
    double? repeatPenalty,
    String? grammar,
  }) {
    _stopRequested = false;
    final controller = StreamController<String>();
    _activeController = controller;

    _doGenerate(
      history,
      userMessage,
      temperature: temperature,
      maxTokens: maxTokens,
      topK: topK,
      topP: topP,
      repeatPenalty: repeatPenalty,
      grammar: grammar,
      controller: controller,
    ).catchError((Object e) {
      print('[$_tag] ERROR: generate error - $e');
      if (!controller.isClosed) {
        controller
          ..addError(e)
          ..close();
      }
    });

    return controller.stream;
  }

  Future<void> _doGenerate(
    List<ChatMessage> history,
    String userMessage, {
    required StreamController<String> controller,
    double? temperature,
    int? maxTokens,
    int? topK,
    double? topP,
    double? repeatPenalty,
    String? grammar,
  }) async {
    if (_isGemma4 && _engine != null) {
      await _doGenerateGemma4(
        history,
        userMessage,
        temperature: temperature,
        maxTokens: maxTokens ?? 512,
        topK: topK,
        topP: topP,
        repeatPenalty: repeatPenalty,
        controller: controller,
      );
      return;
    }

    if (_engine == null) {
      controller.add('Error: No model loaded');
      await controller.close();
      return;
    }

    final messages = <LlamaChatMessage>[];
    for (final msg in history) {
      messages.add(_convertMessage(msg));
    }
    messages.add(
      LlamaChatMessage.fromText(
        role: LlamaChatRole.user,
        text: userMessage,
      ),
    );

    final generationParams = GenerationParams(
      temp: temperature ?? 0.7,
      topK: topK ?? 40,
      topP: topP ?? 0.9,
      penalty: repeatPenalty ?? 1.1,
      maxTokens: maxTokens ?? 512,
      grammar: grammar,
    );

    try {
      await for (final chunk
          in _engine!.create(messages, params: generationParams)) {
        if (_stopRequested || controller.isClosed) break;
        final content = chunk.choices.first.delta.content;
        if (content != null && content.isNotEmpty) {
          controller.add(content);
        }
      }
    } on Object catch (e) {
      print('[$_tag] ERROR: generation stream error - $e');
    }

    if (!controller.isClosed) {
      await controller.close();
    }
  }

  Future<void> _doGenerateGemma4(
    List<ChatMessage> history,
    String userMessage, {
    required double? temperature,
    required int maxTokens,
    required int? topK,
    required double? topP,
    required double? repeatPenalty,
    required StreamController<String> controller,
  }) async {
    final prompt = renderGemma4Prompt(history, userMessage);

    final generationParams = GenerationParams(
      temp: temperature ?? 0.7,
      topK: topK ?? 40,
      topP: topP ?? 0.9,
      penalty: repeatPenalty ?? 1.1,
      maxTokens: maxTokens,
    );

    try {
      await for (final token
          in _engine!.generate(prompt, params: generationParams)) {
        if (_stopRequested || controller.isClosed) break;
        controller.add(token);
      }
    } on Object catch (e) {
      print('[$_tag] ERROR: gemma4 generation error - $e');
    }

    if (!controller.isClosed) {
      await controller.close();
    }
  }

  LlamaChatMessage _convertMessage(ChatMessage msg) {
    return LlamaChatMessage.fromText(
      role: switch (msg.role) {
        'system' => LlamaChatRole.system,
        'assistant' => LlamaChatRole.assistant,
        _ => LlamaChatRole.user,
      },
      text: msg.content,
    );
  }

  @override
  Future<void> stopGeneration() async {
    _stopRequested = true;
    _engine?.cancelGeneration();
    if (_activeController != null && !_activeController!.isClosed) {
      await _activeController!.close();
    }
    _activeController = null;
  }

  @override
  Future<void> saveState(String path) async {
    print('[$_tag] WARN: saveState not yet supported in llamadart');
  }

  @override
  Future<void> loadState(String path) async {
    print('[$_tag] WARN: loadState not yet supported in llamadart');
  }
}
