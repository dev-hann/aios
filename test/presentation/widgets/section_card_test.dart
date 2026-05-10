import 'package:aios/presentation/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapWithMaterial(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: SingleChildScrollView(child: Column(children: [child])),
    ),
  );
}

void main() {
  group('SectionCard', () {
    testWidgets('render_displaysTitleAndIcon', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const SectionCard(
            title: 'General',
            icon: Icons.settings,
            child: SizedBox.shrink(),
          ),
        ),
      );

      expect(find.text('General'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('render_displaysChild', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const SectionCard(
            title: 'Test',
            icon: Icons.star,
            child: Text('Child content'),
          ),
        ),
      );

      expect(find.text('Child content'), findsOneWidget);
    });

    testWidgets('render_multipleCards_displayAllTitles', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SectionCard(
                    title: 'First',
                    icon: Icons.one_k,
                    child: SizedBox.shrink(),
                  ),
                  SectionCard(
                    title: 'Second',
                    icon: Icons.two_k,
                    child: SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
    });
  });
}
