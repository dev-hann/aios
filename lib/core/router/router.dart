import 'package:aios/presentation/screens/chat/chat_screen.dart';
import 'package:aios/presentation/screens/settings/inference_settings_screen.dart';
import 'package:aios/presentation/screens/settings/model_management_screen.dart';
import 'package:aios/presentation/screens/settings/permission_management_screen.dart';
import 'package:aios/presentation/screens/settings/settings_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const ChatScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/model',
        builder: (_, __) => const ModelManagementScreen(),
      ),
      GoRoute(
        path: '/settings/inference',
        builder: (_, __) => const InferenceSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/permissions',
        builder: (_, __) => const PermissionManagementScreen(),
      ),
    ],
  );
});
