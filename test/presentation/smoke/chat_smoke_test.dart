import 'package:aios/domain/agent/agent_strategy.dart';
import 'package:aios/domain/agent/conversation_context.dart';
import 'package:aios/domain/agent/tool_preference_tracker.dart';
import 'package:aios/domain/entities/agent_models.dart';
import 'package:aios/presentation/providers/agent_provider.dart';
import 'package:aios/presentation/providers/conversation_provider.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/providers/update_provider.dart';
import 'package:aios/presentation/screens/chat/chat_screen.dart';
import 'package:aios/presentation/screens/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
  void resolvePermission(bool granted) {}
  @override
  void setPermissionChecker(
    Future<bool> Function(String permissionKey)? checker,
  ) {}
  @override
  void setConversationContext(ConversationContext? context) {}
  @override
  void setToolPreferenceTracker(ToolPreferenceTracker? tracker) {}
}

void main() {
  late MockLlmRepository llmRepo;
  late MockConversationRepository conversationRepo;

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        llmRepositoryProvider.overrideWithValue(llmRepo),
        conversationRepositoryProvider.overrideWithValue(conversationRepo),
        settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
        agentProvider.overrideWithValue(_NoOpAgent()),
      ],
      child: const MaterialApp(home: ChatScreen()),
    );
  }

  Widget buildAppWithRouter() {
    return ProviderScope(
      overrides: [
        llmRepositoryProvider.overrideWithValue(llmRepo),
        conversationRepositoryProvider.overrideWithValue(conversationRepo),
        settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
        agentProvider.overrideWithValue(_NoOpAgent()),
        updateRepositoryProvider.overrideWithValue(MockUpdateRepository()),
        currentVersionProvider.overrideWithValue('1.0.0'),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(path: '/', builder: (_, __) => const ChatScreen()),
            GoRoute(
              path: '/settings',
              builder: (_, __) => const SettingsScreen(),
            ),
          ],
        ),
      ),
    );
  }

  setUp(() {
    llmRepo = MockLlmRepository();
    conversationRepo = MockConversationRepository();
  });

  tearDown(() {
    llmRepo.dispose();
    conversationRepo.dispose();
  });

  group('ChatScreen smoke', () {
    testWidgets('render_hasAllKeyWidgets', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.byIcon(Icons.add_comment_outlined), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets('tap_drawerMenu_opensDrawerWithSettings', (tester) async {
      await tester.pumpWidget(buildAppWithRouter());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      expect(find.text('설정'), findsWidgets);
    });

    testWidgets('tap_settingsInDrawer_navigatesToSettings', (tester) async {
      await tester.pumpWidget(buildAppWithRouter());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.text('설정'), findsOneWidget);
    });

    testWidgets('enterText_sendButton_tapsSuccessfully', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();

      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('tap_newConversationButton_works', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_comment_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
