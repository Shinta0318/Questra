import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Guild migration uses owner-checked RPC and moderation boundaries', () {
    final migration = File(
      '../../supabase/migrations/202607310002_guild_interactions.sql',
    ).readAsStringSync();
    expect(migration, contains('create_guild_post'));
    expect(migration, contains("trim(p_content), 'pending'"));
    expect(migration, contains('join_public_guild'));
    expect(migration, contains('report_guild_post'));
    expect(migration, contains('enable row level security'));
  });
}
