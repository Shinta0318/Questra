import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI telemetry remains metadata-only and bounded', () {
    final root = Directory.current.parent.parent;
    final migration = File(
      '${root.path}/supabase/migrations/202607310003_ai_usage_observability.sql',
    ).readAsStringSync();
    final provider = File(
      '${root.path}/supabase/functions/_shared/ai_provider.ts',
    ).readAsStringSync();

    expect(
      migration,
      contains('create table if not exists public.ai_usage_events'),
    );
    expect(migration, isNot(contains('raw_prompt')));
    expect(migration, isNot(contains('raw_response')));
    expect(provider, contains('recordAiUsage'));
    expect(provider, contains('return=minimal'));
  });
}
