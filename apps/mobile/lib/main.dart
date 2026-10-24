import 'dart:async';

import 'package:app_links/app_links.dart';
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
import 'features/auth/auth_redirects.dart';
import 'features/auth/auth_callback_url_cleanup.dart';
import 'features/auth/password_recovery_service.dart';
import 'features/auth/signup_confirmation_service.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final confirmationUri = kIsWeb ? Uri.base : null;
  final confirmationLink = confirmationUri == null
      ? null
      : AuthRedirects.signupConfirmationLink(confirmationUri);
  final recoveryLink = confirmationUri == null
      ? null
      : AuthRedirects.passwordRecoveryLink(confirmationUri);
  SignupConfirmationStatus? confirmationStatus;
  bool? passwordRecoveryVerified;
  if (SupabaseConfig.isConfigured) {
    if (confirmationLink != null && !confirmationLink.hasLegacyAuthResponse) {
      clearSignupCallbackUrl(
        AuthRedirects.cleanedWebConfirmationUrl(confirmationUri!),
      );
    }
    if (recoveryLink != null) {
      clearSignupCallbackUrl(
        AuthRedirects.cleanedWebPasswordRecoveryUrl(confirmationUri!),
      );
    }
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
      authOptions: FlutterAuthClientOptions(
        detectSessionInUriPredicate: AuthRedirects.shouldExchangeSession,
        localStorage: kIsWeb
            ? const EmptyLocalStorage()
            : const QuestraSecureAuthStorage(),
      ),
    );
    if (confirmationLink != null) {
      if (confirmationLink.hasError) {
        confirmationStatus = SignupConfirmationStatus.invalid;
      } else if (confirmationLink.hasImplicitSession) {
        confirmationStatus = await completeImplicitSignupConfirmation(
          Supabase.instance.client,
          accessToken: confirmationLink.accessToken!,
          refreshToken: confirmationLink.refreshToken!,
        );
      } else if (confirmationLink.tokenHash case final tokenHash?) {
        confirmationStatus = await verifySignupConfirmation(
          Supabase.instance.client,
          tokenHash,
        );
      } else if (confirmationLink.hasLegacyAuthResponse &&
          Supabase.instance.client.auth.currentSession != null) {
        confirmationStatus = SignupConfirmationStatus.verified;
      } else {
        confirmationStatus = SignupConfirmationStatus.invalid;
      }
      clearSignupCallbackUrl(
        AuthRedirects.cleanedWebConfirmationUrl(confirmationUri!),
      );
    }
    if (recoveryLink != null) {
      passwordRecoveryVerified =
          recoveryLink.hasImplicitSession &&
          !recoveryLink.hasError &&
          await completeImplicitPasswordRecovery(
            Supabase.instance.client,
            accessToken: recoveryLink.accessToken!,
            refreshToken: recoveryLink.refreshToken!,
          );
      clearSignupCallbackUrl(
        AuthRedirects.cleanedWebPasswordRecoveryUrl(confirmationUri!),
      );
    }
  }

  runApp(
    ProviderScope(
      child: QuestraApp(
        initialConfirmationStatus: confirmationStatus,
        initialPasswordRecoveryVerified: passwordRecoveryVerified,
      ),
    ),
  );
}

class QuestraApp extends ConsumerStatefulWidget {
  const QuestraApp({
    this.initialConfirmationStatus,
    this.initialPasswordRecoveryVerified,
    super.key,
  });

  final SignupConfirmationStatus? initialConfirmationStatus;
  final bool? initialPasswordRecoveryVerified;

  @override
  ConsumerState<QuestraApp> createState() => _QuestraAppState();
}

class _QuestraAppState extends ConsumerState<QuestraApp> {
  StreamSubscription<Uri>? _confirmationLinks;
  int? _lastConfirmationLinkHash;

  @override
  void initState() {
    super.initState();
    if (widget.initialConfirmationStatus case final status?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(authControllerProvider.notifier)
              .setSignupConfirmationStatus(status);
          ref.read(appRouterProvider).go(AppRoutes.emailConfirmationReturn);
        }
      });
    }
    if (widget.initialPasswordRecoveryVerified case final verified?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (verified) {
          ref.read(authControllerProvider.notifier).activatePasswordRecovery();
        }
        ref.read(appRouterProvider).go(AppRoutes.resetPassword);
      });
    }
    if (!kIsWeb && SupabaseConfig.isConfigured) {
      _confirmationLinks = AppLinks().uriLinkStream.listen(
        _showConfirmationReturn,
        onError: (Object _, StackTrace _) {},
      );
      unawaited(
        AppLinks()
            .getInitialLink()
            .then((uri) {
              if (uri != null) _showConfirmationReturn(uri);
            })
            .catchError((Object _) {}),
      );
    }
  }

  void _showConfirmationReturn(Uri uri) {
    final link = AuthRedirects.signupConfirmationLink(uri);
    if (link == null) return;
    final linkHash = uri.toString().hashCode;
    if (_lastConfirmationLinkHash == linkHash) return;
    _lastConfirmationLinkHash = linkHash;
    ref
        .read(authControllerProvider.notifier)
        .setSignupConfirmationStatus(SignupConfirmationStatus.checking);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(appRouterProvider).go(AppRoutes.emailConfirmationReturn);
      }
    });
    if (link.hasError) {
      ref
          .read(authControllerProvider.notifier)
          .setSignupConfirmationStatus(SignupConfirmationStatus.invalid);
    } else if (link.tokenHash case final tokenHash?) {
      unawaited(
        ref.read(authControllerProvider.notifier).confirmSignupToken(tokenHash),
      );
    } else if (link.hasImplicitSession) {
      unawaited(
        ref
            .read(authControllerProvider.notifier)
            .confirmSignupSession(
              accessToken: link.accessToken!,
              refreshToken: link.refreshToken!,
            ),
      );
    } else if (link.hasLegacyAuthResponse) {
      unawaited(_finishLegacyConfirmation());
    } else {
      ref
          .read(authControllerProvider.notifier)
          .setSignupConfirmationStatus(SignupConfirmationStatus.invalid);
    }
  }

  Future<void> _finishLegacyConfirmation() async {
    final auth = Supabase.instance.client.auth;
    if (auth.currentSession == null) {
      try {
        await auth.onAuthStateChange
            .firstWhere((event) => event.event == AuthChangeEvent.signedIn)
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        // Older links need the SDK's code exchange, which may not succeed.
      }
    }
    if (!mounted) return;
    final controller = ref.read(authControllerProvider.notifier);
    if (auth.currentSession == null) {
      controller.setSignupConfirmationStatus(SignupConfirmationStatus.invalid);
      return;
    }
    await controller.restoreSession();
    if (!mounted) return;
    controller.setSignupConfirmationStatus(
      ref.read(authControllerProvider).isAuthenticated
          ? SignupConfirmationStatus.verified
          : SignupConfirmationStatus.unavailable,
    );
  }

  @override
  void dispose() {
    final links = _confirmationLinks;
    if (links != null) unawaited(links.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
