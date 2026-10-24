import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/auth/auth_redirects.dart';
import 'package:questra/features/auth/password_recovery_service.dart';

void main() {
  test('Web recovery callback accepts only complete recovery credentials', () {
    final callback = Uri.parse(
      'https://questra.example/?auth_callback=recovery'
      '#access_token=opaque-access&refresh_token=opaque-refresh&type=recovery',
    );
    final link = AuthRedirects.passwordRecoveryLink(callback)!;
    expect(link.hasImplicitSession, isTrue);
    expect(link.hasError, isFalse);
    expect(link.accessToken, 'opaque-access');
    expect(link.refreshToken, 'opaque-refresh');
    expect(AuthRedirects.shouldExchangeSession(callback), isFalse);
    expect(
      AuthRedirects.cleanedWebPasswordRecoveryUrl(callback),
      'https://questra.example/#/reset-password',
    );
  });

  test('expired, partial, signup and unrelated links cannot reset password', () {
    for (final uri in [
      'https://questra.example/?auth_callback=recovery&error_code=otp_expired',
      'https://questra.example/?auth_callback=recovery#access_token=only&type=recovery',
      'https://questra.example/?auth_callback=recovery#access_token=one&refresh_token=two&type=signup',
      'https://questra.example/?auth_callback=recovery#access_token=one&refresh_token=two',
    ]) {
      final link = AuthRedirects.passwordRecoveryLink(Uri.parse(uri))!;
      expect(link.hasImplicitSession, isFalse, reason: uri);
      expect(link.hasError, isTrue, reason: uri);
    }
    expect(
      AuthRedirects.passwordRecoveryLink(
        Uri.parse(
          'https://questra.example/?auth_callback=signup'
          '#access_token=one&refresh_token=two&type=recovery',
        ),
      ),
      isNull,
    );
    expect(
      AuthRedirects.passwordRecoveryLink(
        Uri.parse('https://other.example/#/reset-password'),
      ),
      isNull,
    );
  });

  test(
    'Web request uses the current origin without a fixed localhost port',
    () {
      expect(
        AuthRedirects.webPasswordRecovery(
          Uri.parse('https://questra.example/quest#/arc'),
        ),
        'https://questra.example/?auth_callback=recovery',
      );
    },
  );

  test(
    'recovery request does not bind the email link to one browser',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      late Uri requestUri;
      late Map<String, dynamic> requestBody;
      server.listen((request) async {
        requestUri = request.uri;
        requestBody =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        request.response.headers.contentType = ContentType.json;
        request.response.write('{}');
        await request.response.close();
      });
      final client = createPasswordRecoveryEmailClient(
        'http://127.0.0.1:${server.port}',
        'local-test-key',
      );
      addTearDown(() async {
        await client.dispose();
        await server.close(force: true);
      });

      await client.auth.resetPasswordForEmail(
        'test@example.invalid',
        redirectTo: 'http://127.0.0.1:5268/?auth_callback=recovery',
      );

      expect(requestUri.path, '/auth/v1/recover');
      expect(
        requestUri.queryParameters['redirect_to'],
        'http://127.0.0.1:5268/?auth_callback=recovery',
      );
      expect(requestBody['code_challenge'], isNull);
      expect(requestBody['code_challenge_method'], isNull);
    },
  );

  test('a verified callback session can enter password recovery', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'id': 'local-recovery-user',
          'created_at': '2026-01-01T00:00:00Z',
        }),
      );
      await request.response.close();
    });
    final client = createPasswordRecoveryEmailClient(
      'http://127.0.0.1:${server.port}',
      'local-test-key',
    );
    addTearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
    final claims = base64Url.encode(
      utf8.encode(jsonEncode({'iat': now, 'exp': now + 3600})),
    );
    final signature = base64Url.encode([1, 2, 3]);

    final verified = await completeImplicitPasswordRecovery(
      client,
      accessToken: '$header.$claims.$signature',
      refreshToken: 'local-refresh-token',
    );

    expect(verified, isTrue);
    expect(client.auth.currentUser?.id, 'local-recovery-user');
  });

  test(
    'a lock-clear failure still attempts to end the recovery session',
    () async {
      var signOutCalled = false;
      final result = await finalizePasswordReset(
        clearLoginLock: () async => throw StateError('network unavailable'),
        signOut: () async => signOutCalled = true,
      );

      expect(result.loginLockCleared, isFalse);
      expect(result.signedOut, isTrue);
      expect(signOutCalled, isTrue);
    },
  );

  test(
    'a sign-out failure is not reported as a failed password update',
    () async {
      final result = await finalizePasswordReset(
        clearLoginLock: () async {},
        signOut: () async => throw StateError('network unavailable'),
      );

      expect(result.loginLockCleared, isTrue);
      expect(result.signedOut, isFalse);
    },
  );
}
