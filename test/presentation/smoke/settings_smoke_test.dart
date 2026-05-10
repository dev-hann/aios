import 'package:aios/domain/agent/agent_strategy.dart';
import 'package:aios/domain/agent/conversation_context.dart';
import 'package:aios/domain/agent/tool_preference_tracker.dart';
import 'package:aios/domain/entities/agent_models.dart';
import 'package:aios/presentation/providers/agent_provider.dart';
import 'package:aios/presentation/providers/conversation_provider.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/providers/update_provider.dart';
import 'package:aios/presentation/screens/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_conversation_repository.dart';
import '../../helpers/mock_llm_repository.dart';
import '../../helpers/mock_settings_repository.dart';
import '../../helpers/mock_update_repository.dart';

class _NoOpAgent implements AgentStrategy {
  @override
  Future<AgentResult> execute(
    String prompt, {
    int maxIterations = 8,
    int maxTokens = 512,
    void Function(AgentStep)? onStep,
  }) async {
    return const AgentResult(steps: [AgentStep('answer', 'ok')], success: true);
  }

  @override
  Future<void> warmup() async {}
  @override
  void cancel() {}
  @override
  void resolveConfirmation(bool approved) {}
  @override
  void clearHistory() {}
  @override
  String getToolManifest() => '';
  @override
  List<({String role, String content})> getConversationHistory() => [];
  @override
  void setConversationContext(ConversationContext? context) {}
  @override
  void setToolPreferenceTracker(ToolPreferenceTracker? tracker) {}
  @override
  void resolvePermission(bool granted) {}
  @override
  void setPermissionChecker(
    Future<bool> Function(String permissionKey)? checker,
  ) {}
}

void main() {
  late MockLlmRepository llmRepo;

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        llmRepositoryProvider.overrideWithValue(llmRepo),
        conversationRepositoryProvider.overrideWithValue(
          MockConversationRepository(),
        ),
        settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
        agentProvider.overrideWithValue(_NoOpAgent()),
        updateRepositoryProvider.overrideWithValue(MockUpdateRepository()),
        currentVersionProvider.overrideWithValue('1.0.0'),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    );
  }

  setUp(() {
    llmRepo = MockLlmRepository();
  });

  tearDown(() {
    llmRepo.dispose();
  });

  group('SettingsScreen semantics', () {
    testWidgets('render_displaysSettingsTitle', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('설정'), findsOneWidget);
    });

    testWidgets('render_hasInferenceTile', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('settings_inference_tile'), findsOneWidget);
    });

    testWidgets('render_hasPermissionsTile', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('settings_permissions_tile'),
        findsOneWidget,
      );
    });
  });
}
