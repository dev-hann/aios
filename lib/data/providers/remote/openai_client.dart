import 'dart:async';
import 'dart:convert';

import 'package:aios/domain/agent/llm_engine.dart';
import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class OpenAiClient {
  OpenAiClient(this._config) : _dio = Dio();

  final LlmProviderConfig _config;
  final Dio _dio;

  static const _tag = 'AIOS-OpenAiClient';

  Stream<LlmResponseChunk> streamChat({
    required List<Map<String, dynamic>> messages,
    required LlmGenerationConfig config,
    List<LlmToolSchema> tools = const [],
    bool toolStream = true,
  }) async* {
    final body = <String, dynamic>{
      'model': _config.model,
      'messages': messages,
      'stream': true,
      'temperature': config.temperature,
      'top_p': config.topP,
      'max_tokens': config.maxTokens,
    };

    if (tools.isNotEmpty) {
      body['tools'] = _convertTools(tools);
      body['tool_choice'] = 'auto';
      body['tool_stream'] = toolStream;
    }

    try {
      final response = await _dio.post<ResponseBody>(
        _config.chatEndpoint,
        data: jsonEncode(body),
        options: Options(
          headers: _config.headers,
          responseType: ResponseType.stream,
        ),
      );

      final toolCallBuilders = <int, _ToolCallBuilder>{};
      final buffer = StringBuffer();
      var remaining = '';

      await for (final chunk in response.data!.stream) {
        buffer.write(utf8.decode(chunk, allowMalformed: true));
        remaining = buffer.toString();

        while (remaining.contains('\n')) {
          final newlineIndex = remaining.indexOf('\n');
          final line = remaining.substring(0, newlineIndex).trim();
          remaining = remaining.substring(newlineIndex + 1);

          if (line.isEmpty) continue;
          if (line == 'data: [DONE]') break;
          if (!line.startsWith('data: ')) continue;

          final jsonStr = line.substring(6);
          try {
            final data = jsonDecode(jsonStr) as Map<String, dynamic>;
            final choices = data['choices'] as List<dynamic>?;
            if (choices == null || choices.isEmpty) continue;

            final delta =
                (choices[0] as Map<String, dynamic>)['delta']
                    as Map<String, dynamic>? ??
                {};
            final reasoningContent = delta['reasoning_content'] as String?;

            if (delta['content'] != null) {
              yield LlmResponseChunk(text: delta['content'] as String);
            }

            if (reasoningContent != null) {
              yield LlmResponseChunk(thinking: reasoningContent);
            }

            final toolCalls = delta['tool_calls'] as List<dynamic>?;
            if (toolCalls != null) {
              for (final tc in toolCalls) {
                final tcMap = tc as Map<String, dynamic>;
                final index = tcMap['index'] as int? ?? 0;
                final builder = toolCallBuilders.putIfAbsent(
                  index,
                  _ToolCallBuilder.new,
                );

                final id = tcMap['id'] as String?;
                if (id != null) builder.id = id;

                final func = tcMap['function'] as Map<String, dynamic>?;
                if (func != null) {
                  final name = func['name'] as String?;
                  if (name != null) builder.name = name;
                  final args = func['arguments'] as String?;
                  if (args != null) builder.arguments += args;
                }

                yield LlmResponseChunk(
                  toolCallDeltas: [
                    LlmToolCallDelta(
                      index: index,
                      id: id,
                      name: func?['name'] as String?,
                      arguments: func?['arguments'] as String?,
                    ),
                  ],
                );
              }
            }
          } on Object catch (e) {
            print('[$_tag] WARN: SSE parse error - $e');
          }
        }
        buffer
          ..clear()
          ..write(remaining);
      }
    } on DioException catch (e) {
      print('[$_tag] ERROR: HTTP error - ${e.message}');
      if (e.response?.data != null) {
        print('[$_tag] ERROR: body - ${e.response!.data}');
      }
      rethrow;
    } on Object catch (e) {
      print('[$_tag] ERROR: stream error - $e');
      rethrow;
    }
  }

  Future<List<LlmModelInfo>> fetchModels() async {
    try {
      final response = await _dio.get<dynamic>(
        _config.modelsEndpoint,
        options: Options(headers: _config.headers),
      );

      List<dynamic>? modelList;
      final data = response.data;
      if (data is List<dynamic>) {
        modelList = data;
      } else if (data is Map<String, dynamic>) {
        modelList = data['data'] as List<dynamic>?;
      }

      final models = <LlmModelInfo>[];
      for (final item in modelList ?? []) {
        final map = item as Map<String, dynamic>;
        final id = map['id'] as String? ?? '';
        if (id.isNotEmpty) {
          models.add(LlmModelInfo.fromApi(id));
        }
      }
      print('[$_tag] Fetched ${models.length} models');
      return models;
    } on Object catch (e) {
      print('[$_tag] ERROR: fetchModels failed - $e');
      return [];
    }
  }

  Future<bool> testConnection() async {
    try {
      await _dio.post<void>(
        _config.chatEndpoint,
        data: jsonEncode({
          'model': _config.model,
          'messages': [
            {'role': 'user', 'content': 'ping'},
          ],
          'max_tokens': 1,
          'stream': false,
        }),
        options: Options(headers: _config.headers),
      );
      print('[$_tag] Connection test passed');
      return true;
    } on Object catch (e) {
      print('[$_tag] ERROR: Connection test failed - $e');
      return false;
    }
  }

  @visibleForTesting
  List<Map<String, dynamic>> convertTools(List<LlmToolSchema> tools) =>
      _convertTools(tools);

  List<Map<String, dynamic>> _convertTools(List<LlmToolSchema> tools) {
    return tools.map((t) {
      final properties = <String, dynamic>{};
      final requiredParams = <String>[];

      for (final p in t.parameters) {
        final prop = <String, dynamic>{
          'type': p.type,
          'description': p.description,
        };
        if (p.isEnum && p.enumValues != null) {
          prop['enum'] = p.enumValues;
        }
        if (p.example != null) {
          prop['example'] = p.example;
        }
        properties[p.name] = prop;
        if (p.required) requiredParams.add(p.name);
      }

      return {
        'type': 'function',
        'function': {
          'name': t.name,
          'description': t.description,
          'parameters': {
            'type': 'object',
            'properties': properties,
            if (requiredParams.isNotEmpty) 'required': requiredParams,
          },
        },
      };
    }).toList();
  }

  void cancel() {
    _dio.close(force: true);
  }
}

class _ToolCallBuilder {
  String? id;
  String? name;
  String arguments = '';
}
