import 'dart:async';

import 'package:aios/data/providers/llama_engine_provider.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart'
    hide ChatMessage;

class RealLlamaEngineProvider implements LlamaEngineProvider {
  LlamaEngine? _engine;
  EngineChat? _chat;
  EngineSession? _session;
  StreamSubscription<GenerationEvent>? _activeSub;
  StreamController<String>? _activeController;
  bool _stopRequested = false;
  String? _detectedTemplate;
  bool _isGemma4 = false;

  static const _tag = 'AIOS-RealEngine';

  static const _templatePatterns = [
    KnownChatTemplates.commandR,
    KnownChatTemplates.falcon3,
    KnownChatTemplates.deepseek,
    KnownChatTemplates.vicuna,
    KnownChatTemplates.llama3,
    KnownChatTemplates.gemma,
    KnownChatTemplates.chatml,
    KnownChatTemplates.mistral,
    KnownChatTemplates.phi3,
  ];

  static String? _classifyTemplate(String? rawTemplate) {
    if (rawTemplate == null) return null;
    for (final pattern in _templatePatterns) {
      if (rawTemplate.contains(pattern)) return pattern;
    }
    return null;
  }

  static String? classifyTemplateByName(String path) {
    final name = path.toLowerCase();
    if (name.contains('gemma')) return KnownChatTemplates.gemma;
    if (name.contains('llama-3') || name.contains('llama3')) {
      return KnownChatTemplates.llama3;
    }
    if (name.contains('mistral')) return KnownChatTemplates.mistral;
    if (name.contains('phi-3') || name.contains('phi3')) {
      return KnownChatTemplates.phi3;
    }
    if (name.contains('qwen')) return KnownChatTemplates.chatml;
    if (name.contains('deepseek')) return KnownChatTemplates.deepseek;
    if (name.contains('command-r')) return KnownChatTemplates.commandR;
    if (name.contains('vicuna')) return KnownChatTemplates.vicuna;
    if (name.contains('falcon')) return KnownChatTemplates.falcon3;
    return null;
  }

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

      _engine = await LlamaEngine.spawn(
        libraryPath: 'libllama.so',
        modelParams: ModelParams(path: path, gpuLayers: 99, useMmap: true),
        contextParams: ContextParams(nCtx: contextSize ?? 2048),
      );

      if (_isGemma4) {
        _session = await _engine!.createSession();
        print('[$_tag] Model loaded: $path (ctx=${contextSize ?? 2048}, mode=gemma4-session)');
      } else {
        _chat = await _engine!.createChat();
        _detectedTemplate = _classifyTemplate(_engine!.modelChatTemplate)
            ?? classifyTemplateByName(path);

        final rawPresent = _engine!.modelChatTemplate != null;
        final source = _detectedTemplate != null
            ? (_classifyTemplate(_engine!.modelChatTemplate) != null
                ? 'gguf'
                : 'filename')
            : 'native';
        print('[$_tag] Model loaded: $path (ctx=${contextSize ?? 2048}, rawTemplate=$rawPresent, source=$source)');
      }
      return true;
    } on Object catch (e, st) {
      print('[$_tag] ERROR: loadModel failed: $e\n$st');
      _engine = null;
      _chat = null;
      _session = null;
      _detectedTemplate = null;
      _isGemma4 = false;
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
    _session = null;
    _detectedTemplate = null;
    _isGemma4 = false;
    if (_engine != null) {
      await _engine!.dispose();
      _engine = null;
      print('[$_tag] Model released');
    }
  }

  @override
  bool get isModelLoaded =>
      _engine != null && (_chat != null || _session != null);

  String? get detectedTemplate => _detectedTemplate;

  @override
  String getModelInfo() {
    if (_engine == null) return 'No model loaded';
    return 'Engine active '
        '(accelerator: ${_engine!.primaryAcceleratorName ?? 'CPU'})';
  }

  @override
  String getContextUsage() {
    if (_isGemma4) return 'session active';
    if (_chat == null) return '0/0 tokens';
    return '${_chat!.messageCount} messages';
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
  }) async {
    final sampler = SamplerParams(
      temperature: temperature ?? 0.7,
      topK: topK ?? 40,
      topP: topP ?? 0.9,
      repeatPenalty: repeatPenalty ?? 1.1,
    );

    if (_isGemma4 && _session != null) {
      await _doGenerateGemma4(
        history,
        userMessage,
        sampler: sampler,
        maxTokens: maxTokens ?? 512,
        controller: controller,
      );
      return;
    }

    if (_chat == null) {
      controller.add('Error: No model loaded');
      await controller.close();
      return;
    }

    final chat = _chat!
      ..clearHistory();

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

    final eventStream = chat.generate(
      sampler: sampler,
      maxTokens: maxTokens ?? 512,
      templateOverride: _detectedTemplate,
    );

    await _processEvents(eventStream, controller);
  }

  Future<void> _doGenerateGemma4(
    List<ChatMessage> history,
    String userMessage, {
    required SamplerParams sampler,
    required int maxTokens,
    required StreamController<String> controller,
  }) async {
    final prompt = renderGemma4Prompt(history, userMessage);
    await _session!.clear();

    final shiftPolicy = _engine!.canShift
        ? ContextShiftPolicy.auto
        : ContextShiftPolicy.off;

    final eventStream = _session!.generate(
      prompt: prompt,
      addSpecial: true,
      sampler: sampler,
      maxTokens: maxTokens,
      shiftPolicy: shiftPolicy,
    );

    await _processEvents(eventStream, controller);
  }

  Future<void> _processEvents(
    Stream<GenerationEvent> eventStream,
    StreamController<String> controller,
  ) async {
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
    if (_isGemma4 && _session != null) {
      await _session!.saveState(path);
    } else {
      await _chat?.saveState(path);
    }
    print('[$_tag] Session saved: $path');
  }

  @override
  Future<void> loadState(String path) async {
    if (_isGemma4 && _session != null) {
      await _session!.loadState(path);
    } else {
      await _chat?.loadState(path);
    }
    print('[$_tag] Session loaded: $path');
  }
}
