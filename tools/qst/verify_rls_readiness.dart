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
];

const requiredSnippets = [
  'owner_id = auth.uid()',
  'user_id = auth.uid()',
  "visibility = 'public'",
  "visibility = 'guild'",
  'public.is_guild_member',
  'public.is_guild_owner',
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
