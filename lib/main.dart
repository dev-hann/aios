import 'package:aios/core/router/router.dart';
import 'package:aios/core/theme/theme.dart';
import 'package:aios/data/datasources/local/database.dart';
import 'package:aios/data/datasources/remote/github_api.dart';
import 'package:aios/data/providers/remote/llm_remote_engine.dart';
import 'package:aios/data/providers/tool_context_impl.dart';
import 'package:aios/data/repositories/conversation_repository_impl.dart';
import 'package:aios/data/repositories/llm_repository_impl.dart';
import 'package:aios/data/repositories/note_repository_impl.dart';
import 'package:aios/data/repositories/settings_repository_impl.dart';
import 'package:aios/data/repositories/update_repository_impl.dart';
import 'package:aios/presentation/providers/agent_provider.dart';
import 'package:aios/presentation/providers/conversation_provider.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/providers/update_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsRepo = SettingsRepositoryImpl();
  await settingsRepo.init();

  final packageInfo = await PackageInfo.fromPlatform();
  final appDatabase = _db;

  runApp(
    ProviderScope(
      overrides: [
        agentEngineProvider.overrideWith((ref) {
          final config = ref.watch(providerConfigProvider);
          if (config == null) return null;
          return LlmRemoteEngine(config);
        }),
        llmRepositoryProvider.overrideWithValue(LlmRepositoryImpl()),
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
        updateRepositoryProvider.overrideWithValue(
          UpdateRepositoryImpl(
            api: GitHubApi(repo: 'dev-hann/aios'),
            currentVersion: packageInfo.version,
            dio: Dio(),
          ),
        ),
        currentVersionProvider.overrideWithValue(packageInfo.version),
        toolContextProvider.overrideWithValue(ToolContextImpl()),
        conversationRepositoryProvider.overrideWithValue(
          ConversationRepositoryImpl(appDatabase),
        ),
        noteRepositoryProvider.overrideWithValue(
          NoteRepositoryImpl(appDatabase),
        ),
      ],
      child: const AIOSApp(),
    ),
  );
}

class AIOSApp extends ConsumerWidget {
  const AIOSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'AIOS',
      debugShowCheckedModeBanner: false,
      theme: aiosDarkTheme,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

AppDatabase? _instance;
AppDatabase get _db => _instance ??= AppDatabase();
