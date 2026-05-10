import 'package:aios/presentation/widgets/nav_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapWithMaterial(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('NavTile', () {
    testWidgets('render_displaysIconAndTitle', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          NavTile(icon: Icons.settings, title: 'Settings', onTap: () {}),
        ),
      );

      expect(find.text('Settings'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('render_withSubtitle_displaysSubtitle', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          NavTile(
            icon: Icons.settings,
            title: 'Settings',
            subtitle: 'Configure app',
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Configure app'), findsOneWidget);
    });

    testWidgets('render_withoutSubtitle_noSubtitleText', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          NavTile(icon: Icons.settings, title: 'Settings', onTap: () {}),
        ),
      );

      final listTile = tester.widget<ListTile>(find.byType(ListTile));
      expect(listTile.subtitle, isNull);
    });

    testWidgets('tap_callsOnTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrapWithMaterial(
          NavTile(
            icon: Icons.settings,
            title: 'Settings',
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('render_customTrailing_displaysTrailing', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          NavTile(
            icon: Icons.settings,
            title: 'Settings',
            onTap: () {},
            trailing: const Icon(Icons.check),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('render_defaultTrailing_showsChevron', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          NavTile(icon: Icons.settings, title: 'Settings', onTap: () {}),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('render_hasSemantics', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          NavTile(
            icon: Icons.settings,
            title: 'Settings',
            onTap: () {},
            semanticsLabel: 'settings_tile',
          ),
        ),
      );

      final semanticsFinder = find.bySemanticsLabel('settings_tile');
      expect(semanticsFinder, findsOneWidget);
    });
  });
}
