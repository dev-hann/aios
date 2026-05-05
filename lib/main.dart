import 'package:aios/core/router/router.dart';
import 'package:aios/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: AIOSApp()));
}

class AIOSApp extends ConsumerWidget {
  const AIOSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'AIOS',
      debugShowCheckedModeBanner: false,
      theme: aiosTheme,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
