import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/auth/auth_error_feedback.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('wrong credentials remain generic', () {
    final error = loginFunctionFailure(
      const FunctionsHttpException(
        status: 401,
        details: {'code': 'invalid_credentials'},
      ),
    );
    expect(
      friendlyAuthError(error, AuthErrorContext.login),
      contains('ログインIDまたはパスワード'),
    );
  });

  test(
    'server, relay, and network failures are not called bad credentials',
    () {
      for (final error in [
        const FunctionsHttpException(status: 503),
        const FunctionsRelayException(status: 404),
        const FunctionsFetchException(),
      ]) {
        final message = friendlyAuthError(
          loginFunctionFailure(error),
          AuthErrorContext.login,
        );
        expect(message, contains('ログインサービス'));
        expect(message, isNot(contains('パスワード違い')));
      }
    },
  );

  test('rate limit offers a retry later', () {
    final error = loginFunctionFailure(
      const FunctionsHttpException(
        status: 429,
        details: {'code': 'rate_limited'},
      ),
    );
    expect(friendlyAuthError(error, AuthErrorContext.login), contains('少し待って'));
  });

  test('unclassified upstream failure is not called bad credentials', () {
    for (final error in [
      const FunctionsHttpException(status: 503),
      const FunctionsHttpException(
        status: 401,
        details: {'code': 'unexpected_failure'},
      ),
    ]) {
      final feedback = friendlyAuthError(
        loginFunctionFailure(error),
        AuthErrorContext.login,
      );
      expect(feedback, contains('ログインサービス'));
      expect(feedback, isNot(contains('ログインIDまたはパスワード')));
    }
  });

  test('signup explains when Supabase rejects an email address', () {
    final message = friendlyAuthError(
      const AuthException(
        'Email address is invalid',
        code: 'email_address_invalid',
      ),
      AuthErrorContext.signup,
    );
    expect(message, contains('受信できるメールアドレス'));
  });

  test('legal consent failure is not described as a login failure', () {
    final message = friendlyAuthError(
      const AuthException('legal_acceptance_not_recorded'),
      AuthErrorContext.legalConsent,
    );
    expect(message, contains('同意を保存できませんでした'));
    expect(message, isNot(contains('ログインIDまたはパスワード')));
  });

  test('signup preflight failure explains service readiness', () {
    final message = friendlyAuthError(
      const AuthException('signup_unavailable', code: 'signup_unavailable'),
      AuthErrorContext.signup,
    );
    expect(message, contains('新規登録の準備が整っていません'));
    expect(message, isNot(contains('パスワード')));
  });

  test('signup refuses stale app policy without presenting old terms', () {
    final message = friendlyAuthError(
      const AuthException('app_update_required', code: 'app_update_required'),
      AuthErrorContext.signup,
    );
    expect(message, contains('Questraを更新'));
    expect(message, isNot(contains('パスワード')));
  });
}
