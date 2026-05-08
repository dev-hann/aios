import 'package:aios/core/router/router.dart';
import 'package:aios/core/theme/theme.dart';
import 'package:aios/data/datasources/local/database.dart';
import 'package:aios/data/datasources/remote/github_api.dart';
import 'package:aios/data/providers/real_llama_engine_provider.dart';
import 'package:aios/data/providers/tool_context_impl.dart';
import 'package:aios/data/repositories/conversation_repository_impl.dart';
import 'package:aios/data/repositories/llm_repository_impl.dart';
import 'package:aios/data/repositories/model_repository_impl.dart';
import 'package:aios/data/repositories/settings_repository_impl.dart';
import 'package:aios/data/repositories/update_repository_impl.dart';
import 'package:aios/presentation/providers/agent_provider.dart';
import 'package:aios/presentation/providers/conversation_provider.dart';
import 'package:aios/presentation/providers/llm_provider.dart';
import 'package:aios/presentation/providers/model_provider.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:aios/presentation/providers/update_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsRepo = SettingsRepositoryImpl();
  await settingsRepo.init();

  final appDir = await getApplicationDocumentsDirectory();
  final modelsDir = '${appDir.path}/models';
  final downloadsDir = '${appDir.path}/downloads';

  final packageInfo = await PackageInfo.fromPlatform();

  final appDatabase = AppDatabase();
  final llamaEngine = RealLlamaEngineProvider();

  runApp(
    ProviderScope(
      overrides: [
        engineProvider.overrideWithValue(llamaEngine),
        llamaEngineProvider.overrideWithValue(llamaEngine),
        llmRepositoryProvider.overrideWithValue(
          LlmRepositoryImpl(llamaEngine),
        ),
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
        modelRepositoryProvider.overrideWithValue(
          ModelRepositoryImpl(
            modelsDir: modelsDir,
            downloadsDir: downloadsDir,
          ),
        ),
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
      ],
      child: const AIOSApp(),
    ),
  );
}

class AIOSApp extends ConsumerWidget {
  const AIOSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      title: 'AIOS',
      debugShowCheckedModeBanner: false,
      theme: aiosThemeOf(settings.themeMode),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
