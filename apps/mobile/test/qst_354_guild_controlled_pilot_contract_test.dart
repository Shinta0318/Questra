import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '../../supabase/migrations/202608250003_guild_controlled_pilot_atomic_copy.sql',
  ).readAsStringSync();

  test('discovery is restricted to an enabled pilot cohort', () {
    expect(migration, contains('guild_pilot_members'));
    expect(migration, contains('member.user_id = auth.uid() and member.enabled'));
    expect(
      migration,
      contains('drop policy if exists "Guild Discovery reads approved public snapshots"'),
    );
    expect(migration, contains('list_guild_pilot_quests'));
    expect(migration, contains('(publication.published_at,publication.id) <'));
  });

  test('copy RPC creates a private Quest and is idempotent', () {
    expect(migration, contains('copy_guild_quest_to_private'));
    expect(migration, contains("'active','private'"));
    expect(migration, contains('where copier_id=v_actor and idempotency_key=p_idempotency_key'));
    expect(migration, contains("'already_applied',true"));
    expect(migration, contains('source_snapshot_version'));
    expect(migration, contains('version_guild_quest_snapshot'));
  });

  test('moderation appeals are owner-scoped', () {
    expect(migration, contains('guild_moderation_appeals'));
    expect(migration, contains('ownership.owner_id=auth.uid()'));
  });

  test('optional Missions and first Task derive from immutable copy fields', () {
    expect(migration, contains('guild_mission_capture_copy_contract'));
    expect(migration, contains('if p_include_missions then'));
    expect(migration, contains("'ready','copied'"));
    expect(migration, contains('source rows are never modified'));
  });
}
