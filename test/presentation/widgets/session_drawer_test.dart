import 'package:aios/core/theme/app_strings.dart';
import 'package:aios/domain/agent/agent_strategy.dart';
import 'package:aios/domain/agent/conversation_context.dart';
import 'package:aios/domain/agent/tool_preference_tracker.dart';
import 'package:aios/domain/entities/agent_models.dart';
import '../../helpers/mock_conversation_repository.dart';
import '../../helpers/mock_llm_repository.dart';
import '../../helpers/mock_settings_repository.dart';
import 'package:aios/presentation/providers/agent_provider.dart';
import 'package:aios/presentation/providers/conversation_provider.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/widgets/session_drawer.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubAgent implements AgentStrategy {
  @override
  Future<AgentResult> execute(
    String prompt, {
    int maxIterations = 8,
    int maxTokens = 512,
    void Function(AgentStep)? onStep,
  }) async {
    return AgentResult(steps: [], success: true);
  }

  @override
  void cancel() {}

  @override
  void resolveConfirmation(bool approved) {}

  @override
  void resolvePermission(bool granted) {}

  @override
  void setPermissionChecker(
    Future<bool> Function(String permissionKey)? checker,
  ) {}

  @override
  String getToolManifest() => '';

  @override
  List<({String role, String content})> getConversationHistory() => [];

  @override
  void clearHistory() {}

  @override
  Future<void> warmup() async {}

  @override
  void setConversationContext(ConversationContext? context) {}

  @override
  void setToolPreferenceTracker(ToolPreferenceTracker? tracker) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionDrawer', () {
    MockLlmRepository? llmRepo;
    MockConversationRepository? convRepo;

    Widget buildWidget() {
      llmRepo = MockLlmRepository();
      convRepo = MockConversationRepository();

      return ProviderScope(
        overrides: [
          llmRepositoryProvider.overrideWithValue(llmRepo!),
          conversationRepositoryProvider.overrideWithValue(convRepo!),
          settingsRepositoryProvider.overrideWithValue(
            MockSettingsRepository(),
          ),
          agentProvider.overrideWithValue(_StubAgent()),
        ],
        child: MaterialApp(
          home: Scaffold(body: const SizedBox(), drawer: const SessionDrawer()),
        ),
      );
    }

    tearDown(() {
      llmRepo?.dispose();
      convRepo?.dispose();
    });

    Future<void> openDrawer(WidgetTester tester) async {
      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pump();
    }

    testWidgets('render_displaysAppName', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();
      await openDrawer(tester);

      expect(find.text(Strings.appName), findsOneWidget);
    });

    testWidgets('render_displaysNewChatButton', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();
      await openDrawer(tester);

      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    });

    testWidgets('render_displaysSettingsTile', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();
      await openDrawer(tester);

      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      expect(find.text(Strings.drawer.settings), findsOneWidget);
    });

    testWidgets('render_hasDrawerStructure', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();
      await openDrawer(tester);

      expect(find.byType(Drawer), findsOneWidget);
      expect(find.byType(Divider), findsAtLeast(1));
    });
  });
}
