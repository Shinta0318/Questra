import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/router/app_routes.dart';
import 'package:questra/core/router/auth_route_guard.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_redirects.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/auth/email_confirmation_return_screen.dart';
import 'package:questra/features/auth/signup_confirmation_service.dart';
import 'package:questra/main.dart';

void main() {
  test('default confirmation passes one session to Questra', () {
    final web = Uri.parse(
      'https://questra.example/?auth_callback=signup#access_token=opaque-access&refresh_token=opaque-refresh&type=signup',
    );
    final optionalTokenHash = Uri.parse(
      'https://questra.example/?auth_callback=signup#token_hash=opaque&type=email',
    );
    final legacy = Uri.parse('https://questra.example/?code=old-code#/login');
    final native = Uri.parse(
      'com.questra.questra://login-callback/confirm?code=one-time-code',
    );
    final nativeImplicit = Uri.parse(
      'com.questra.questra://login-callback/confirm?auth_callback=signup#access_token=mobile-access&refresh_token=mobile-refresh&type=signup',
    );

    for (final uri in [
      web,
      optionalTokenHash,
      legacy,
      native,
      nativeImplicit,
    ]) {
      expect(AuthRedirects.isSignupConfirmationReturn(uri), isTrue);
    }
    final link = AuthRedirects.signupConfirmationLink(web)!;
    expect(link.hasImplicitSession, isTrue);
    expect(link.accessToken, 'opaque-access');
    expect(link.refreshToken, 'opaque-refresh');
    expect(AuthRedirects.shouldExchangeSession(web), isFalse);
    expect(
      AuthRedirects.signupConfirmationLink(optionalTokenHash)?.tokenHash,
      'opaque',
    );
    expect(AuthRedirects.shouldExchangeSession(optionalTokenHash), isFalse);
    expect(AuthRedirects.shouldExchangeSession(legacy), isTrue);
    expect(AuthRedirects.shouldExchangeSession(native), isTrue);
    expect(
      AuthRedirects.signupConfirmationLink(nativeImplicit)?.hasImplicitSession,
      isTrue,
    );
    expect(AuthRedirects.shouldExchangeSession(nativeImplicit), isFalse);
    expect(
      AuthRedirects.cleanedWebConfirmationUrl(web),
      'https://questra.example/#/email-confirmation-return',
    );
    expect(
      AuthRedirects.cleanedWebConfirmationUrl(legacy),
      'https://questra.example/#/email-confirmation-return',
    );
  });

  test('malformed, expired and unrelated callbacks cannot sign in', () {
    final malformed = Uri.parse(
      'https://questra.example/?auth_callback=signup#token_hash=opaque&type=recovery',
    );
    final expired = Uri.parse(
      'https://questra.example/?auth_callback=signup&error_code=otp_expired',
    );
    final partial = Uri.parse(
      'https://questra.example/?auth_callback=signup#access_token=opaque&type=signup',
    );
    final wrongType = Uri.parse(
      'https://questra.example/?auth_callback=signup#access_token=opaque&refresh_token=other&type=recovery',
    );
    expect(AuthRedirects.signupConfirmationLink(malformed)?.hasError, isTrue);
    expect(AuthRedirects.signupConfirmationLink(expired)?.hasError, isTrue);
    expect(AuthRedirects.signupConfirmationLink(partial)?.hasError, isTrue);
    expect(AuthRedirects.signupConfirmationLink(wrongType)?.hasError, isTrue);
    expect(AuthRedirects.shouldExchangeSession(malformed), isFalse);
    expect(AuthRedirects.shouldExchangeSession(expired), isFalse);
    expect(
      AuthRedirects.signupConfirmationLink(
        Uri.parse('https://questra.example/?token_hash=opaque&type=email'),
      ),
      isNull,
    );
  });

  test('password recovery keeps its exchange while other routes do not', () {
    expect(
      AuthRedirects.shouldExchangeSession(
        Uri.parse('https://questra.example/?code=recovery#/reset-password'),
      ),
      isTrue,
    );
    expect(
      AuthRedirects.shouldExchangeSession(
        Uri.parse('com.questra.questra://login-callback?code=recovery'),
      ),
      isTrue,
    );
    expect(
      AuthRedirects.shouldExchangeSession(
        Uri.parse('https://questra.example/?code=unrelated#/quest'),
      ),
      isFalse,
    );
    expect(
      AuthRedirects.shouldExchangeSession(
        Uri.parse('com.questra.questra://other?code=unrelated'),
      ),
      isFalse,
    );
  });

  test('callback is a public route without a current session', () {
    expect(
      AuthRouteGuard.redirect(
        auth: const AuthState(),
        location: Uri.parse(AppRoutes.emailConfirmationReturn),
        persistenceAvailable: true,
      ),
      isNull,
    );
  });

  test('confirmed session continues to legal consent or onboarding', () {
    const profile = UserProfile(
      id: 'confirmed-user',
      email: 'example@questra.test',
      nickname: 'example',
    );
    expect(
      AuthRouteGuard.redirect(
        auth: const AuthState(profile: profile),
        location: Uri.parse(AppRoutes.emailConfirmationReturn),
        persistenceAvailable: true,
      ),
      AppRoutes.legalConsent,
    );
    expect(
      AuthRouteGuard.redirect(
        auth: const AuthState(
          profile: UserProfile(
            id: 'confirmed-user',
            email: 'example@questra.test',
            nickname: 'example',
            legalAcceptanceCurrent: true,
          ),
        ),
        location: Uri.parse(AppRoutes.emailConfirmationReturn),
        persistenceAvailable: true,
      ),
      AppRoutes.onboarding,
    );
  });

  test(
    'Web scrubs signup tokens before SDK startup and restores afterward',
    () {
      final source = File('lib/main.dart').readAsStringSync();
      expect(source, contains('clearSignupCallbackUrl('));
      expect(source, contains('AuthRedirects.shouldExchangeSession'));
      expect(source, contains('completeImplicitSignupConfirmation('));
      expect(
        source.indexOf('clearSignupCallbackUrl('),
        lessThan(source.indexOf('await Supabase.initialize(')),
      );
      expect(
        source.indexOf('completeImplicitSignupConfirmation('),
        greaterThan(source.indexOf('await Supabase.initialize(')),
      );
    },
  );

  test('signup and resend use an isolated implicit client only', () {
    final source = File(
      'lib/features/auth/auth_controller.dart',
    ).readAsStringSync();
    expect(source, contains('createSignupEmailClient('));
    expect(source, contains('await signupClient.dispose()'));
    expect(source, contains('Supabase.instance.client.functions.invoke('));
  });

  testWidgets('invalid return shows resend instead of silent login', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_InvalidConfirmation.new),
        ],
        child: const MaterialApp(home: EmailConfirmationReturnScreen()),
      ),
    );
    final resend = find.text('確認メールを再送する');
    await tester.ensureVisible(resend);
    await tester.pumpAndSettle();
    expect(resend.hitTestable(), findsOneWidget);
    expect(find.textContaining('期限切れ'), findsOneWidget);
    expect(find.text('ログインへ進む'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup callback does not mutate auth during widget build', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: QuestraApp(
          initialConfirmationStatus: SignupConfirmationStatus.invalid,
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

class _InvalidConfirmation extends AuthController {
  @override
  AuthState build() => const AuthState(
    signupConfirmationStatus: SignupConfirmationStatus.invalid,
  );
}
