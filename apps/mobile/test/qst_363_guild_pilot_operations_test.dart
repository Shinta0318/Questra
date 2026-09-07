import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '../../supabase/migrations/202608250005_guild_pilot_operations_and_metrics.sql',
  ).readAsStringSync();

  test('pilot entry is explicit and non-members cannot read discovery', () {
    expect(migration, contains('get_guild_pilot_status'));
    expect(migration, contains('guild_pilot_not_enabled'));
    final router = File('lib/core/router/app_router.dart').readAsStringSync();
    expect(router, contains('GuildDiscoveryScreen'));
    expect(router, isNot(contains("featureName: 'Guild'")));
  });

  test(
    'copy and first progress metrics are server-derived and metadata-only',
    () {
      expect(migration, contains('capture_guild_copy_metric'));
      expect(migration, contains('capture_guild_first_progress_metric'));
      expect(migration, contains("'first_progress_completed'"));
      expect(migration, contains('Quest, Mission, Task, Trail, Arc chat'));
    },
  );

  test('moderation and appeals require an allowlisted operator', () {
    expect(migration, contains('is_guild_pilot_operator'));
    expect(migration, contains('resolve_guild_publication_moderation'));
    expect(migration, contains('resolve_guild_moderation_appeal'));
    expect(migration, contains("raise exception 'operator_required'"));
    expect(migration, contains('guild_pilot_moderation_events'));
  });

  test('pilot metrics are aggregate and avoid user identifiers', () {
    expect(migration, contains('get_guild_pilot_metrics'));
    expect(migration, contains("'copy_to_first_progress_rate'"));
    expect(migration, isNot(contains("'owner_id',")));
  });
}
