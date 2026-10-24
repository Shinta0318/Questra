import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/auth/signup_confirmation_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OtpType;

void main() {
  test(
    'confirmed link establishes a session without password reentry',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'id': 'local-confirmed-user',
            'created_at': '2026-01-01T00:00:00Z',
            'email_confirmed_at': '2026-01-01T00:00:00Z',
          }),
        );
        await request.response.close();
      });
      final client = createSignupEmailClient(
        'http://127.0.0.1:${server.port}',
        'local-test-key',
      );
      addTearDown(() async {
        await client.dispose();
        await server.close(force: true);
      });
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final header = base64Url.encode(
        utf8.encode('{"alg":"HS256","typ":"JWT"}'),
      );
      final claims = base64Url.encode(
        utf8.encode(jsonEncode({'iat': now, 'exp': now + 3600})),
      );
    final signature = base64Url.encode([1, 2, 3]);
      final result = await completeImplicitSignupConfirmation(
        client,
      accessToken: '$header.$claims.$signature',
        refreshToken: 'local-refresh-token',
      );

      expect(result, SignupConfirmationStatus.verified);
      expect(client.auth.currentUser?.id, 'local-confirmed-user');
    },
  );

  test(
    'signup and resend do not attach browser-bound PKCE challenges',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final bodies = <Map<String, dynamic>>[];
      server.listen((request) async {
        bodies.add(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>,
        );
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          request.uri.path.endsWith('/signup')
              ? '{"id":"local-test","created_at":"2026-01-01"}'
              : '{}',
        );
        await request.response.close();
      });
      final client = createSignupEmailClient(
        'http://127.0.0.1:${server.port}',
        'local-test-key',
      );
      addTearDown(() async {
        await client.dispose();
        await server.close(force: true);
      });

      await client.auth.signUp(
        email: 'test@example.invalid',
        password: 'local-only-test-password',
        emailRedirectTo: 'http://127.0.0.1:5268/?auth_callback=signup',
      );
      await client.auth.resend(
        type: OtpType.signup,
        email: 'test@example.invalid',
        emailRedirectTo: 'http://127.0.0.1:5268/?auth_callback=signup',
      );

      expect(bodies, hasLength(2));
      for (final body in bodies) {
        expect(body['code_challenge'], isNull);
        expect(body['code_challenge_method'], isNull);
      }
    },
  );
}
