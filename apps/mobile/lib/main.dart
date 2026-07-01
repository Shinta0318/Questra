import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/layout/questra_scroll_behavior.dart';
import 'core/router/app_router.dart';
import 'core/theme/questra_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  }

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
      scrollBehavior: const QuestraScrollBehavior(),
      routerConfig: router,
    );
  }
}
