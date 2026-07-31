import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/auth/secure_auth_storage.dart';
import 'core/layout/questra_scroll_behavior.dart';
import 'core/router/app_router.dart';
import 'core/router/app_routes.dart';
import 'core/theme/questra_theme.dart';
import 'features/auth/auth_controller.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: kIsWeb
            ? const EmptyLocalStorage()
            : const QuestraSecureAuthStorage(),
      ),
    );
  }

  runApp(const ProviderScope(child: QuestraApp()));
}

class QuestraApp extends ConsumerWidget {
  const QuestraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    ref.listen<bool>(
      authControllerProvider.select((state) => state.isPasswordRecovery),
      (previous, next) {
        if (!next || previous == true) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          router.go(AppRoutes.resetPassword);
        });
      },
    );

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: QuestraTheme.light,
      scrollBehavior: const QuestraScrollBehavior(),
      routerConfig: router,
    );
  }
}
