import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Web release headers deny framing and unsafe active content', () {
    final headers = File('web/_headers').readAsStringSync();
    expect(headers, contains("default-src 'self'"));
    expect(headers, contains("object-src 'none'"));
    expect(headers, contains("frame-ancestors 'none'"));
    expect(headers, contains('X-Content-Type-Options: nosniff'));
    expect(headers, contains('Referrer-Policy: strict-origin-when-cross-origin'));
  });

  test('Edge CORS does not use a wildcard origin', () {
    final http = File(
      '../../supabase/functions/_shared/http.ts',
    ).readAsStringSync();
    expect(http, isNot(contains('"Access-Control-Allow-Origin": "*"')));
    expect(http, contains('WEB_APP_ORIGIN'));
    expect(http, contains('Origin not allowed'));
  });
}
