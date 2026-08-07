import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('experience settings migration keeps rows owner-bound', () {
    final migration = File(
      '../../supabase/migrations/202607200001_user_experience_settings.sql',
    ).readAsStringSync();

    expect(migration, contains('enable row level security'));
    expect(migration, contains('auth.uid() = user_id'));
    expect(migration, contains("to authenticated"));
    expect(migration, isNot(contains('grant select on table')));
  });
}
