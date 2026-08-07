import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '../../supabase/migrations/202607250003_guild_discovery_persistence.sql',
  ).readAsStringSync();

  test('public snapshots keep ownership and source ids in separate tables', () {
    final publicTable = _tableBody(migration, 'guild_quest_publications');
    expect(publicTable, isNot(contains('owner_id')));
    expect(publicTable, isNot(contains('source_quest_id')));
    expect(publicTable, isNot(contains('arc_memory')));
    expect(publicTable, isNot(contains('trail')));
    expect(migration, contains('guild_quest_publication_owners'));
  });

  test('only moderated public snapshots are globally readable', () {
    expect(
      migration,
      contains("visibility = 'public' and moderation_status = 'approved'"),
    );
    expect(migration, contains('enable row level security'));
    expect(migration, contains('revoke all on public.guild_quest_publications'));
  });

  test('publication and copy writes use owner-checking RPC boundaries', () {
    expect(migration, contains('security definer'));
    expect(migration, contains('where id = p_quest_id and owner_id = actor_id'));
    expect(
      migration,
      contains('where id = p_destination_quest_id and owner_id = actor_id'),
    );
    expect(migration, contains('unique (copier_id, idempotency_key)'));
    expect(migration, contains('moderation_status = \'pending\''));
  });
}

String _tableBody(String migration, String tableName) {
  final start = migration.indexOf('create table public.$tableName');
  final end = migration.indexOf('\n);', start);
  expect(start, isNonNegative);
  expect(end, greaterThan(start));
  return migration.substring(start, end);
}
