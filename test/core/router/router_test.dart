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

    test('routerProvider_hasExactlyFiveRoutes', () {
      expect(router.configuration.routes.length, 5);
    });

    test('routerProvider_hasChatRoute', () {
      final routes = router.configuration.routes.whereType<GoRoute>();
      expect(routes.any((r) => r.path == '/'), isTrue);
    });

    test('routerProvider_hasSettingsRoute', () {
      final routes = router.configuration.routes.whereType<GoRoute>();
      expect(routes.any((r) => r.path == '/settings'), isTrue);
    });

    test('routerProvider_hasProviderSettingsRoute', () {
      final routes = router.configuration.routes.whereType<GoRoute>();
      expect(routes.any((r) => r.path == '/settings/provider'), isTrue);
    });

    test('routerProvider_hasInferenceSettingsRoute', () {
      final routes = router.configuration.routes.whereType<GoRoute>();
      expect(routes.any((r) => r.path == '/settings/inference'), isTrue);
    });

    test('routerProvider_hasPermissionsRoute', () {
      final routes = router.configuration.routes.whereType<GoRoute>();
      expect(routes.any((r) => r.path == '/settings/permissions'), isTrue);
    });

    test('chatRoute_hasBuilder', () {
      final routes = router.configuration.routes.whereType<GoRoute>();
      final chatRoute = routes.firstWhere((r) => r.path == '/');
      expect(chatRoute.builder, isNotNull);
    });

    test('settingsRoute_hasBuilder', () {
      final routes = router.configuration.routes.whereType<GoRoute>();
      final settingsRoute = routes.firstWhere((r) => r.path == '/settings');
      expect(settingsRoute.builder, isNotNull);
    });

    test('providerSettingsRoute_hasBuilder', () {
      final routes = router.configuration.routes.whereType<GoRoute>();
      final providerRoute = routes.firstWhere(
        (r) => r.path == '/settings/provider',
      );
      expect(providerRoute.builder, isNotNull);
    });

    test('inferenceSettingsRoute_hasBuilder', () {
      final routes = router.configuration.routes.whereType<GoRoute>();
      final inferenceRoute = routes.firstWhere(
        (r) => r.path == '/settings/inference',
      );
      expect(inferenceRoute.builder, isNotNull);
    });

    test('permissionsRoute_hasBuilder', () {
      final routes = router.configuration.routes.whereType<GoRoute>();
      final permRoute = routes.firstWhere(
        (r) => r.path == '/settings/permissions',
      );
      expect(permRoute.builder, isNotNull);
    });
  });
}
