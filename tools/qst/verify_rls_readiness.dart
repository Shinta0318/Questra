import 'dart:io';

const migrationDir = 'supabase/migrations';
const behaviorTestPath = 'supabase/tests/rls_behavior.sql';

const requiredRlsTables = [
  'quests',
  'missions',
  'trails',
  'trail_events',
  'arc_memories',
  'media',
  'tags',
  'entity_tags',
  'arc_emotion_events',
  'quest_milestones',
  'guild_quest_publications',
  'guild_quest_publication_owners',
  'guild_mission_publications',
  'guild_mission_publication_owners',
  'guild_quest_copy_events',
  'route_versions',
  'route_change_proposals',
  'route_change_items',
  'mission_progress_events',
  'quest_progress_events',
  'quest_stage_state',
  'quest_stage_history',
  'quest_dna_versions',
  'business_quest_signals',
  'mission_support_profiles',
  'consent_purposes',
  'user_consents',
  'support_interactions',
  'contribution_outcomes',
  'segment_definitions',
  'segment_snapshots',
  'segment_access_audit',
  'tasks',
  'mission_dependencies',
  'task_dependencies',
  'hierarchy_migration_previews',
  'task_progress_events',
];

const requiredPolicies = [
  'Quest visibility follows owner public or guild',
  'Users create their own quests',
  'Users update their own quests',
  'Users delete their own quests',
  'Mission visibility follows related quest',
  'Quest owners create missions',
  'Quest owners update missions',
  'Quest owners delete missions',
  'Trail visibility follows owner public or guild',
  'Users create their own trails',
  'Users update their own trails',
  'Users delete their own trails',
  'Trail event visibility follows trail',
  'Trail owners create trail events',
  'Arc memories are strictly owner private',
  'Users create their own Arc memories',
  'Users update their own Arc memories',
  'Users delete their own Arc memories',
  'Media visibility follows owner public or guild',
  'Users create their own media records',
  'Users update their own media records',
  'Users delete their own media records',
  'Users read their own tags',
  'Users create their own tags',
  'Users update their own tags',
  'Users delete their own tags',
  'Users read their own entity tags',
  'Users create their own entity tags',
  'Users update their own entity tags',
  'Users delete their own entity tags',
  'Users read their own Arc emotion events',
  'Users create their own Arc emotion events',
  'Users delete their own Arc emotion events',
  'Quest milestone visibility follows related quest',
  'Quest owners create milestones',
  'Quest owners update milestones',
  'Quest owners delete milestones',
  'Guild Discovery reads approved public snapshots',
  'Guild publication ownership is owner private',
  'Guild Mission Discovery follows approved publication',
  'Guild Mission ownership is owner private',
  'Guild copy events are copier private',
  'Users read their own progress events',
  'Owners manage Quest stage',
  'Owners read Quest stage history',
  'Owners manage Quest DNA versions',
  'Owners manage Mission support profiles',
  'Anyone reads active consent purposes',
  'Users read own consents',
  'Users manage own support interactions',
  'Users read own contribution outcomes',
];

const requiredSnippets = [
  'owner_id = auth.uid()',
  'user_id = auth.uid()',
  "visibility = 'public'",
  "visibility = 'guild'",
  'public.is_guild_member',
  'public.is_guild_owner',
  'create policy route_versions_owner_all',
  'create policy route_proposals_owner_all',
  'create policy route_items_owner_all',
  'create policy mission_progress_events_owner_all',
  'revoke insert, update, delete on public.quest_progress_events',
  'No client policy exists for Business signals',
  'Client access is intentionally absent',
  'create policy tasks_owner_all',
  'create policy mission_dependencies_owner_all',
  'create policy task_dependencies_owner_all',
  'create policy hierarchy_migration_previews_owner',
  'create policy task_progress_events_owner',
];

const requiredBehaviorSnippets = [
  'set local role authenticated;',
  'request.jwt.claim.sub',
  'owner can read own private Quest',
  'owner cannot read another private Mission',
  'other cannot read owner private Trail',
  'other cannot read owner Arc Memory',
  'other cannot read owner private media row',
  'other cannot create a Quest for owner',
  'other cannot create an Arc Memory for owner',
  'other cannot read pending Guild publication',
  'other cannot read Guild publication ownership',
  'source owner cannot inspect copier event',
  'owner can read own private Route version',
  'other cannot read owner private Route proposal',
  'other cannot create a Route version for owner',
  'other cannot read owner progress event',
  'other cannot read owner Quest DNA version',
  'other cannot read owner consent',
  'Business signal is not client-readable',
  'owner can read own private Task',
  'other cannot read owner private Task',
  'other cannot create a Task for owner',
  'rollback;',
];

void main() {
  final migrationDirectory = Directory(migrationDir);
  if (!migrationDirectory.existsSync()) {
    _fail(['Missing migration directory: $migrationDir']);
  }

  final sql = migrationDirectory
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.sql'))
      .map((file) => file.readAsStringSync())
      .join('\n');
  final failures = <String>[];

  for (final table in requiredRlsTables) {
    final statement = 'alter table public.$table enable row level security;';
    if (!sql.contains(statement)) {
      failures.add('Missing RLS enablement: $statement');
    }
  }

  for (final policy in requiredPolicies) {
    if (!sql.contains('create policy "$policy"')) {
      failures.add('Missing policy: $policy');
    }
  }

  for (final snippet in requiredSnippets) {
    if (!sql.contains(snippet)) {
      failures.add('Missing policy guard snippet: $snippet');
    }
  }

  final behaviorTest = File(behaviorTestPath);
  if (!behaviorTest.existsSync()) {
    failures.add('Missing RLS behavior test harness: $behaviorTestPath');
  } else {
    final behaviorSql = behaviorTest.readAsStringSync();
    for (final snippet in requiredBehaviorSnippets) {
      if (!behaviorSql.contains(snippet)) {
        failures.add('Missing behavior test snippet: $snippet');
      }
    }
  }

  if (failures.isNotEmpty) {
    _fail(failures);
  }

  stdout.writeln('RLS readiness verification passed.');
  stdout.writeln('Checked ${requiredRlsTables.length} RLS tables.');
  stdout.writeln('Checked ${requiredPolicies.length} required policies.');
  stdout.writeln('Checked database-backed behavior test harness.');
}

Never _fail(List<String> failures) {
  stderr.writeln('RLS readiness verification failed:');
  for (final failure in failures) {
    stderr.writeln('- $failure');
  }
  exit(1);
}
