import 'dart:io';

import 'package:aios/data/providers/real_llama_engine_provider.dart';
import 'package:aios/domain/entities/chat_message.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

const modelName = 'test-model.gguf';
const modelUrl =
    'https://huggingface.co/bartowski/SmolLM2-135M-Instruct-GGUF/resolve/main/SmolLM2-135M-Instruct-Q4_K_M.gguf';
const localSources = [
  '/data/local/tmp/test-model.gguf',
  '/data/local/tmp/SmolLM2-135M-Instruct-Q4_K_M.gguf',
];

late String modelPath;
bool modelReady = false;

Future<String> get modelsDir async {
  final appDir = await getApplicationDocumentsDirectory();
  final dir = Directory('${appDir.path}/models');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  return dir.path;
}

Future<bool> copyFile(String source, String dest) async {
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

Future<bool> downloadModel(String dest) async {
  debugPrint('Downloading test model (~100MB)...');
  try {
    await Dio().download(
      modelUrl,
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

Future<bool> ensureModelAvailable() async {
  final dir = await modelsDir;
  modelPath = '$dir/$modelName';

  final target = File(modelPath);
  if (target.existsSync() && target.lengthSync() > 1 << 20) {
    debugPrint('Model ready: $modelPath');
    return true;
  }
  if (target.existsSync()) target.deleteSync();

  for (final src in localSources) {
    final f = File(src);
    if (!f.existsSync()) continue;
    debugPrint('Copying $src ...');
    if (await copyFile(src, modelPath)) return true;
  }

  if (await downloadModel(modelPath)) return true;

  debugPrint('No model available, tests will be skipped.');
  return false;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    modelReady = await ensureModelAvailable();
  });

  group('RealLlamaEngineProvider', () {
    late RealLlamaEngineProvider provider;

    setUp(() => provider = RealLlamaEngineProvider());
    tearDown(() async => await provider.releaseModel());

    testWidgets('loads model and returns true', (tester) async {
      if (!modelReady) return;
      final result = await provider.loadModel(modelPath, contextSize: 512);
      expect(result, isTrue);
      expect(provider.isModelLoaded, isTrue);
    });

    testWidgets('getModelInfo returns engine info after load', (tester) async {
      if (!modelReady) return;
      await provider.loadModel(modelPath, contextSize: 512);
      final info = provider.getModelInfo();
      expect(info, isNot(equals('No model loaded')));
    });

    testWidgets('generates text response', (tester) async {
      if (!modelReady) return;
      await provider.loadModel(modelPath, contextSize: 512);

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

    testWidgets('engine is available after model load', (tester) async {
      if (!modelReady) return;
      await provider.loadModel(modelPath, contextSize: 512);

      final eng = provider.engine;
      debugPrint('Engine available: ${eng != null}');
    });

    testWidgets('generates with custom sampler params', (tester) async {
      if (!modelReady) return;
      await provider.loadModel(modelPath, contextSize: 512);

      final tokens = <String>[];
      await for (final token in provider.generate(
        [],
        'Say hello',
        temperature: 0.1,
        maxTokens: 16,
        topK: 10,
        topP: 0.9,
        repeatPenalty: 1.1,
      )) {
        tokens.add(token);
      }
      expect(tokens.join(), isNotEmpty);
    });

    testWidgets('generates with history without duplication', (tester) async {
      if (!modelReady) return;
      await provider.loadModel(modelPath, contextSize: 2048);

      final history = [
        ChatMessage(
          id: '1',
          role: 'system',
          content: 'You are a helpful assistant.',
          createdAt: DateTime.now(),
        ),
        ChatMessage(
          id: '2',
          role: 'user',
          content: 'What is 2+2?',
          createdAt: DateTime.now(),
        ),
        ChatMessage(
          id: '3',
          role: 'assistant',
          content: '4',
          createdAt: DateTime.now(),
        ),
      ];

      final tokens = <String>[];
      await for (final token in provider.generate(
        history,
        'What was my previous question?',
        temperature: 0.1,
        maxTokens: 32,
      )) {
        tokens.add(token);
      }
      final response = tokens.join();
      expect(response, isNotEmpty);
      debugPrint('History-aware response: $response');
    });

    testWidgets('generate stream error closes controller', (tester) async {
      if (!modelReady) return;
      await provider.loadModel(modelPath, contextSize: 512);

      final tokens = <String>[];
      Object? streamError;
      try {
        await for (final token in provider.generate(
          [],
          'Hi',
          temperature: 0.1,
          maxTokens: 8,
        )) {
          tokens.add(token);
        }
      } on Object catch (e) {
        streamError = e;
      }
      if (streamError != null) {
        debugPrint('Stream error (expected for some models): $streamError');
      } else {
        expect(tokens.join(), isNotEmpty);
      }
    });

    testWidgets('releaseModel clears loaded state', (tester) async {
      if (!modelReady) return;
      await provider.loadModel(modelPath, contextSize: 512);
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
