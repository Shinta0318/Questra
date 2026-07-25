import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth migration defines bounded login lock and private grants', () {
    final sql = File(
      '../../supabase/migrations/202607190001_auth_login_hardening.sql',
    ).readAsStringSync();

    expect(sql, contains("interval '15 minutes'"));
    expect(sql, contains('next_count >= 10'));
    expect(sql, contains("interval '30 minutes'"));
    expect(
      sql,
      contains(
        'revoke all on table public.auth_login_accounts from anon, authenticated, public',
      ),
    );
    expect(sql, contains('should_logout_user'));
    expect(sql, contains('false'));
  });

  test('auth login function bounds input and prevents response caching', () {
    final source = File(
      '../../supabase/functions/auth-login/index.ts',
    ).readAsStringSync();

    expect(source, contains('MAX_BODY_BYTES = 4_096'));
    expect(source, contains('cache-control'));
    expect(source, contains('no-store'));
    expect(source, contains('ALLOWED_WEB_ORIGINS'));
    expect(source, isNot(contains('console.log')));
  });

  test('Supabase config enables recovery and auth enforcement contracts', () {
    final config = File('../../supabase/config.toml').readAsStringSync();

    expect(config, contains('com.questra.questra://login-callback'));
    expect(config, contains('[functions.auth-login]'));
    expect(config, contains('verify_jwt = false'));
    expect(config, contains('[auth.hook.password_verification_attempt]'));
  });
}
