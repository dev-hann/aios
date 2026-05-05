import 'dart:async';
import 'dart:developer' as developer;

import 'package:aios/data/providers/llama_engine_provider.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:aios/domain/entities/service_state.dart';
import 'package:aios/domain/repositories/llm_repository.dart';

class LlmRepositoryImpl implements LlmRepository {
  LlmRepositoryImpl(this._provider);

  final LlamaEngineProvider _provider;

  final _stateController =
      StreamController<ServiceState>.broadcast(sync: true);
  final _tokenController = StreamController<String>.broadcast(sync: true);
  final _progressController = StreamController<double>.broadcast(sync: true);

  StreamSubscription<String>? _generationSubscription;
  Completer<void>? _generationCompleter;

  static const _tag = 'AIOS-LlmRepo';

  void _emitState(ServiceState state) {
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  void _emitToken(String token) {
    if (!_tokenController.isClosed) {
      _tokenController.add(token);
    }
  }

  void _emitProgress(double progress) {
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }

  @override
  Stream<ServiceState> get state => _stateController.stream;

  @override
  Stream<String> get tokenStream => _tokenController.stream;

  @override
  Stream<double> get loadProgress => _progressController.stream;

  @override
  Future<bool> loadModel(String path, {int? contextSize}) async {
    _emitState(ServiceState.loadingModel);
      _emitProgress(0);

    try {
      final result = await _provider.loadModel(path, contextSize: contextSize);

      if (result) {
        _emitProgress(1);
        _emitState(ServiceState.ready);
        developer.log('Model loaded: $path', name: _tag);
      } else {
        _emitState(ServiceState.error);
        developer.log(
          'Model load failed: $path',
          name: _tag,
          level: 1000,
        );
      }

      return result;
    } on Object catch (e) {
      _emitState(ServiceState.error);
      developer.log(
        'loadModel failed',
        name: _tag,
        error: e,
        level: 1000,
      );
      return false;
    }
  }

  @override
  Future<void> releaseModel() async {
    try {
      await _provider.releaseModel();
      _emitState(ServiceState.idle);
      developer.log('Model released', name: _tag);
    } on Object catch (e) {
      developer.log(
        'releaseModel failed',
        name: _tag,
        error: e,
        level: 1000,
      );
      _emitState(ServiceState.idle);
    }
  }

  @override
  bool get isModelLoaded => _provider.isModelLoaded;

  @override
  String getModelInfo() => _provider.getModelInfo();

  @override
  String getContextUsage() => _provider.getContextUsage();

  @override
  Future<void> resetContext() async {
    if (_provider.isModelLoaded) {
      _emitState(ServiceState.ready);
    }
  }

  @override
  Future<void> sendMessage(
    List<ChatMessage> history, {
    required String userMessage,
    double? temperature,
    int? maxTokens,
  }) async {
    if (!_provider.isModelLoaded) {
      developer.log(
        'sendMessage called without loaded model',
        name: _tag,
        level: 900,
      );
      _emitState(ServiceState.error);
      return;
    }

    _emitState(ServiceState.generating);

    try {
      final tokenStream = _provider.generate(
        history,
        userMessage,
        temperature: temperature,
        maxTokens: maxTokens,
      );

      _generationCompleter = Completer<void>();

      _generationSubscription = tokenStream.listen(
        _emitToken,
        onDone: () {
          _generationSubscription?.cancel();
          _generationSubscription = null;
          if (!_stateController.isClosed) {
            _emitState(ServiceState.ready);
          }
          if (!_generationCompleter!.isCompleted) {
            _generationCompleter!.complete();
          }
        },
        onError: (Object e) {
          _generationSubscription?.cancel();
          _generationSubscription = null;
          _emitState(ServiceState.ready);
          developer.log(
            'Generation error',
            name: _tag,
            error: e,
            level: 1000,
          );
          if (!_generationCompleter!.isCompleted) {
            _generationCompleter!.complete();
          }
        },
        cancelOnError: true,
      );

      await _generationCompleter!.future;
    } on Object catch (e) {
      _emitState(ServiceState.ready);
      developer.log(
        'sendMessage failed',
        name: _tag,
        error: e,
        level: 1000,
      );
    }
  }

  @override
  Future<void> stopGeneration() async {
    await _provider.stopGeneration();
    await _generationSubscription?.cancel();
    _generationSubscription = null;
    if (_generationCompleter != null && !_generationCompleter!.isCompleted) {
      _generationCompleter!.complete();
    }
    _emitState(ServiceState.ready);
    developer.log('Generation stopped', name: _tag);
  }

  @override
  Future<void> saveSession(String path) async {
    await _provider.saveState(path);
    developer.log('Session saved: $path', name: _tag);
  }

  @override
  Future<void> loadSession(String path) async {
    await _provider.loadState(path);
    developer.log('Session loaded: $path', name: _tag);
  }

  void dispose() {
    _generationSubscription?.cancel();
    _stateController.close();
    _tokenController.close();
    _progressController.close();
  }
}
