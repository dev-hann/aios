import 'dart:convert';

import 'package:aios/agent/tools/app_launcher_tool.dart';
import 'package:aios/agent/tools/screen_action_tool.dart';
import 'package:aios/agent/tools/screen_reader_tool.dart';
import 'package:aios/data/providers/remote/llm_remote_engine.dart';
import 'package:aios/data/providers/tool_context_impl.dart';
import 'package:aios/domain/agent/react_strategy.dart';
import 'package:aios/domain/entities/llm_provider_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('youtube_search_e2e', (tester) async {
    const apiKey = String.fromEnvironment('TEST_API_KEY', defaultValue: '');
    if (apiKey.isEmpty) {
      debugPrint('[TEST] SKIPPED: no API key');
      return;
    }

    final config = LlmProviderConfig(
      type: LlmProviderType.zaiCoding,
      apiKey: apiKey,
      model: const String.fromEnvironment(
        'TEST_MODEL',
        defaultValue: 'glm-4.5-air',
      ),
    );

    print('[TEST] Starting with ${config.model}');
    final engine = LlmRemoteEngine(config);
    final toolContext = ToolContextImpl();

    print('[TEST] Waiting for accessibility service...');
    bool accessibilityReady = false;
    for (int i = 0; i < 30; i++) {
      final ready = await toolContext.isAccessibilityEnabled();
      if (ready) {
        print('[TEST] Accessibility service ready after ${i + 1}s');
        accessibilityReady = true;
        break;
      }
      if (i == 29) {
        print('[TEST] WARN: Accessibility service not ready after 30s');
      }
      await Future.delayed(const Duration(seconds: 1));
    }

    if (!accessibilityReady) {
      print('[TEST] SKIPPED: Accessibility service not enabled');
      return;
    }

    final strategy = ReactStrategy(
      engine: engine,
      toolContext: toolContext,
      extendedTools: {
        'app_launcher': AppLauncherTool(),
        'screen_action': ScreenActionTool(),
        'screen_reader': ScreenReaderTool(),
      },
    );

    final result = await strategy.execute(
      '유튜브에서 한동근 검색해서 첫번째 영상 틀어줘',
      maxIterations: 12,
      maxTokens: 256,
    );

    print('[TEST] === Steps (${result.steps.length}) ===');
    for (final step in result.steps) {
      String argsDisplay = '';
      if (step.toolArgs.isNotEmpty) {
        try {
          final d = jsonDecode(step.toolArgs) as Map<String, dynamic>;
          argsDisplay =
              ' a=${d['action']} c=${d['content']} t=${d['text']} g=${d['global_action']}';
        } on Object {
          argsDisplay = ' ${step.toolArgs}';
        }
      }
      final content = step.content.length > 50
          ? '${step.content.substring(0, 50)}...'
          : step.content;
      print(
        '[TEST]   ${step.type}: ${step.toolName ?? ""}$argsDisplay | $content',
      );
    }

    final actions = result.steps
        .where((s) => s.type == 'action' && s.toolName == 'screen_action')
        .map((s) {
          try {
            return (jsonDecode(s.toolArgs) as Map<String, dynamic>)['action'];
          } on Object {
            return null;
          }
        })
        .toList();
    print('[TEST] screen_action sequence: $actions');

    final hasType = actions.contains('type');
    final hasEnter = result.steps.any((s) {
      if (s.toolName != 'screen_action' || s.type != 'action') return false;
      try {
        final d = jsonDecode(s.toolArgs) as Map<String, dynamic>;
        return d['action'] == 'global' && d['global_action'] == 'enter';
      } on Object {
        return false;
      }
    });

    print(
      '[TEST] hasType=$hasType hasEnter=$hasEnter success=${result.success}',
    );
    expect(hasType, isTrue, reason: 'Should type search query');
    expect(hasEnter, isTrue, reason: 'Should press enter after typing');
    print('[TEST] PASSED');
  });
}
