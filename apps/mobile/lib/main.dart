import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/questra_theme.dart';

void main() {
  runApp(const ProviderScope(child: QuestraApp()));
}

class QuestraApp extends ConsumerWidget {
  const QuestraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Questra',
      debugShowCheckedModeBanner: false,
      theme: QuestraTheme.light,
      routerConfig: router,
    );
  }
}
