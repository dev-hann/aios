import 'dart:io';

import 'package:aios/data/providers/real_llama_engine_provider.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

const _modelName = 'test-model.gguf';
const _modelUrl =
    'https://huggingface.co/bartowski/SmolLM2-135M-Instruct-GGUF/resolve/main/SmolLM2-135M-Instruct-Q4_K_M.gguf';
const _localSources = [
  '/data/local/tmp/test-model.gguf',
  '/data/local/tmp/SmolLM2-135M-Instruct-Q4_K_M.gguf',
];

late String _modelPath;
bool _modelReady = false;

Future<String> get _modelsDir async {
  final appDir = await getApplicationDocumentsDirectory();
  final dir = Directory('${appDir.path}/models');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  return dir.path;
}

Future<bool> _copyFile(String source, String dest) async {
  try {
    final input = File(source).openRead();
    final output = File(dest).openWrite();
    await input.pipe(output);
    return true;
  } on Object catch (e) {
    debugPrint('  copy failed: $e');
    try {
      await File(dest).delete();
    } on Object catch (_) {}
    return false;
  }
}

Future<bool> _downloadModel(String dest) async {
  debugPrint('Downloading test model (~100MB)...');
  try {
    await Dio().download(
      _modelUrl,
      dest,
      onReceiveProgress: (received, total) {
        if (total > 0 && received % (5 << 20) < (1 << 20)) {
          debugPrint(
            '  ${(received * 100 / total).toStringAsFixed(0)}% '
            '(${received >> 20}MB / ${total >> 20}MB)',
          );
        }
      },
    );
    debugPrint('Done: ${File(dest).lengthSync()} bytes');
    return true;
  } on Object catch (e) {
    debugPrint('Download failed: $e');
    try {
      await File(dest).delete();
    } on Object catch (_) {}
    return false;
  }
}

Future<bool> _ensureModelAvailable() async {
  final dir = await _modelsDir;
  _modelPath = '$dir/$_modelName';

  final target = File(_modelPath);
  if (target.existsSync() && target.lengthSync() > 1 << 20) {
    debugPrint('Model ready: $_modelPath');
    return true;
  }
  if (target.existsSync()) target.deleteSync();

  for (final src in _localSources) {
    final f = File(src);
    if (!f.existsSync()) continue;
    debugPrint('Copying $src ...');
    if (await _copyFile(src, _modelPath)) return true;
  }

  if (await _downloadModel(_modelPath)) return true;

  debugPrint('No model available, tests will be skipped.');
  return false;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _modelReady = await _ensureModelAvailable();
  });

  group('RealLlamaEngineProvider', () {
    late RealLlamaEngineProvider provider;

    setUp(() => provider = RealLlamaEngineProvider());
    tearDown(() async => await provider.releaseModel());

    testWidgets('loads model and returns true', (tester) async {
      if (!_modelReady) return;
      final result = await provider.loadModel(_modelPath, contextSize: 512);
      expect(result, isTrue);
      expect(provider.isModelLoaded, isTrue);
    });

    testWidgets('getModelInfo returns engine info after load', (tester) async {
      if (!_modelReady) return;
      await provider.loadModel(_modelPath, contextSize: 512);
      final info = provider.getModelInfo();
      expect(info, isNot(equals('No model loaded')));
    });

    testWidgets('generates text response', (tester) async {
      if (!_modelReady) return;
      await provider.loadModel(_modelPath, contextSize: 512);

      final tokens = <String>[];
      await for (final token in provider.generate(
        [],
        'Hello',
        temperature: 0.1,
        maxTokens: 16,
      )) {
        tokens.add(token);
      }
      expect(tokens.join(), isNotEmpty);
    });

    testWidgets('releaseModel clears loaded state', (tester) async {
      if (!_modelReady) return;
      await provider.loadModel(_modelPath, contextSize: 512);
      expect(provider.isModelLoaded, isTrue);
      await provider.releaseModel();
      expect(provider.isModelLoaded, isFalse);
      expect(provider.getModelInfo(), equals('No model loaded'));
    });

    testWidgets('loadModel with invalid path returns false', (tester) async {
      final result = await provider.loadModel('/no/model.gguf');
      expect(result, isFalse);
      expect(provider.isModelLoaded, isFalse);
    });

    testWidgets('generate without model returns error', (tester) async {
      final tokens = <String>[];
      await for (final token in provider.generate([], 'Hi')) {
        tokens.add(token);
      }
      expect(tokens.join(), contains('Error'));
    });
  });
}
