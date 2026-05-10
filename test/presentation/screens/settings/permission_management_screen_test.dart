import 'package:aios/core/theme/app_strings.dart';
import 'package:aios/presentation/screens/settings/permission_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _createTestWidget() {
  return const MaterialApp(home: PermissionManagementScreen());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.agent.aios/tools'), (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'isAccessibilityEnabled') return false;
          if (methodCall.method == 'openAccessibilitySettings') return null;
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.agent.aios/tools'),
          null,
        );
  });

  testWidgets('build_rendersAppBarTitle', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text(Strings.permission.title), findsOneWidget);
  });

  testWidgets('build_rendersStoragePermission', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text(Strings.permission.storage), findsOneWidget);
  });

  testWidgets('build_rendersNotificationsPermission', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text(Strings.permission.notifications), findsOneWidget);
  });

  testWidgets('build_rendersContactsPermission', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text(Strings.permission.contacts), findsOneWidget);
  });

  testWidgets('build_rendersPhonePermission', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text(Strings.permission.phone), findsOneWidget);
  });

  testWidgets('build_rendersSmsPermission', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text(Strings.permission.sms), findsOneWidget);
  });

  testWidgets('build_rendersAccessibilityPermission', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text(Strings.permission.accessibility), findsOneWidget);
  });

  testWidgets('build_showsGrantButtons_whenNotGranted', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();

    final grantButtons = find.text(Strings.permission.grant);
    expect(grantButtons, findsWidgets);
  });

  testWidgets('build_showsGrantPrompt', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text(Strings.permission.storageDesc), findsOneWidget);
    expect(find.text(Strings.permission.notificationsDesc), findsOneWidget);
    expect(find.text(Strings.permission.contactsDesc), findsOneWidget);
    expect(find.text(Strings.permission.phoneDesc), findsOneWidget);
    expect(find.text(Strings.permission.smsDesc), findsOneWidget);
    expect(find.text(Strings.permission.accessibilityDesc), findsOneWidget);
  });

  testWidgets('build_rendersSixPermissionTiles', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();

    final tiles = find.byType(ListTile);
    expect(tiles, findsNWidgets(6));
  });

  testWidgets('build_hasPermissionIcons', (tester) async {
    await tester.pumpWidget(_createTestWidget());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.folder), findsOneWidget);
    expect(find.byIcon(Icons.notifications), findsOneWidget);
    expect(find.byIcon(Icons.contacts), findsOneWidget);
    expect(find.byIcon(Icons.phone), findsOneWidget);
    expect(find.byIcon(Icons.sms), findsOneWidget);
    expect(find.byIcon(Icons.accessibility_new), findsOneWidget);
  });
}
