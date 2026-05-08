import 'package:aios/presentation/screens/chat/chat_screen.dart';
import 'package:aios/presentation/screens/settings/settings_screen.dart';
import 'package:aios/presentation/screens/update/update_screen.dart';
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
        path: '/update',
        builder: (_, __) => const UpdateScreen(),
      ),
    ],
  );
});
