import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/router/app_routes.dart';
import 'package:questra/core/router/auth_route_guard.dart';
import 'package:questra/features/auth/auth_state.dart';

void main() {
  const incompleteProfile = UserProfile(
    id: 'user-1',
    email: 'captain@example.com',
    nickname: 'Captain',
    legalAcceptanceCurrent: true,
  );
  const completeProfile = UserProfile(
    id: 'user-1',
    email: 'captain@example.com',
    nickname: 'Captain',
    onboardingCompleted: true,
    legalAcceptanceCurrent: true,
  );

  group('AuthRouteGuard', () {
    test('blocks every protected route when persistence is unavailable', () {
      expect(
        AuthRouteGuard.redirect(
          auth: const AuthState(),
          location: Uri.parse('/quest/quest-1'),
          persistenceAvailable: false,
        ),
        AppRoutes.splash,
      );
    });

    test('preserves a protected deep link while restoring a session', () {
      final redirect = AuthRouteGuard.redirect(
        auth: const AuthState(isLoading: true),
        location: Uri.parse('/quest/quest-1?mode=plan'),
        persistenceAvailable: true,
      );

      expect(Uri.parse(redirect!).path, AppRoutes.splash);
      expect(
        Uri.parse(redirect).queryParameters['continue'],
        '/quest/quest-1?mode=plan',
      );
    });

    test('sends an unauthenticated deep link to login with continuation', () {
      final redirect = AuthRouteGuard.redirect(
        auth: const AuthState(),
        location: Uri.parse('/quest/quest-1?mode=plan'),
        persistenceAvailable: true,
      );

      expect(Uri.parse(redirect!).path, AppRoutes.login);
      expect(
        Uri.parse(redirect).queryParameters['continue'],
        '/quest/quest-1?mode=plan',
      );
    });

    test('routes an incomplete profile to onboarding', () {
      expect(
        AuthRouteGuard.redirect(
          auth: const AuthState(profile: incompleteProfile),
          location: Uri.parse(AppRoutes.home),
          persistenceAvailable: true,
        ),
        AppRoutes.onboarding,
      );
    });

    test(
      'blocks an authenticated profile without current legal acceptance',
      () {
        const profile = UserProfile(
          id: 'user-2',
          email: 'legacy@example.com',
          nickname: 'Legacy',
        );
        expect(
          AuthRouteGuard.redirect(
            auth: const AuthState(profile: profile),
            location: Uri.parse(AppRoutes.home),
            persistenceAvailable: true,
          ),
          AppRoutes.legalConsent,
        );
      },
    );

    test('returns a complete profile to its safe continuation', () {
      expect(
        AuthRouteGuard.redirect(
          auth: const AuthState(profile: completeProfile),
          location: Uri.parse(
            '/login?continue=%2Fquest%2Fquest-1%3Fmode%3Dplan',
          ),
          persistenceAvailable: true,
        ),
        '/quest/quest-1?mode=plan',
      );
    });

    test('rejects external and public continuations', () {
      expect(
        AuthRouteGuard.safeContinuation('https://example.com/quest'),
        isNull,
      );
      expect(AuthRouteGuard.safeContinuation('//example.com/quest'), isNull);
      expect(AuthRouteGuard.safeContinuation(AppRoutes.login), isNull);
    });

    test('allows recovery route only for an active recovery session', () {
      expect(
        AuthRouteGuard.redirect(
          auth: const AuthState(
            profile: completeProfile,
            isPasswordRecovery: true,
          ),
          location: Uri.parse(AppRoutes.resetPassword),
          persistenceAvailable: true,
        ),
        isNull,
      );
    });
  });
}
