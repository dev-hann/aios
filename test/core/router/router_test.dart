import 'package:aios/core/router/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('routerProvider', () {
    late ProviderContainer container;
    late GoRouter router;

    setUp(() {
      container = ProviderContainer();
      router = container.read(routerProvider);
    });

    tearDown(() {
      container.dispose();
    });

    test('shouldHaveExactlyThreeRoutes', () {
      expect(router.configuration.routes.length, 3);
    });

    test('shouldHaveChatRoute', () {
      final routes = router.configuration.routes.whereType<GoRoute>();
      expect(routes.any((r) => r.path == '/'), isTrue);
    });

    test('shouldHaveSettingsRoute', () {
      final routes = router.configuration.routes.whereType<GoRoute>();
      expect(routes.any((r) => r.path == '/settings'), isTrue);
    });

    test('shouldHaveUpdateRoute', () {
      final routes = router.configuration.routes.whereType<GoRoute>();
      expect(routes.any((r) => r.path == '/update'), isTrue);
    });

    test('chatRoute_shouldHaveBuilder', () {
      final routes = router.configuration.routes.whereType<GoRoute>();
      final chatRoute = routes.firstWhere((r) => r.path == '/');
      expect(chatRoute.builder, isNotNull);
    });

    test('settingsRoute_shouldHaveBuilder', () {
      final routes = router.configuration.routes.whereType<GoRoute>();
      final settingsRoute = routes.firstWhere((r) => r.path == '/settings');
      expect(settingsRoute.builder, isNotNull);
    });

    test('updateRoute_shouldHaveBuilder', () {
      final routes = router.configuration.routes.whereType<GoRoute>();
      final updateRoute = routes.firstWhere((r) => r.path == '/update');
      expect(updateRoute.builder, isNotNull);
    });
  });
}
