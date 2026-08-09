import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('database guards the four-level hierarchy and Mission completion', () {
    final root =
        Directory.current.path.endsWith('${Platform.pathSeparator}mobile')
        ? Directory.current.parent.parent
        : Directory.current;
    final migration = File(
      '${root.path}/supabase/migrations/202608080002_quest_mission_task_trail_integrity.sql',
    ).readAsStringSync();
    final repository = File(
      '${root.path}/apps/mobile/lib/features/mission/mission_repository.dart',
    ).readAsStringSync();
    final deleteFix = File(
      '${root.path}/supabase/migrations/202608080003_trail_parent_delete_integrity_fix.sql',
    ).readAsStringSync();
    final allRolesGuard = File(
      '${root.path}/supabase/migrations/202608080004_mission_completion_guard_all_roles.sql',
    ).readAsStringSync();

    expect(migration, contains('task_parent_mismatch'));
    expect(migration, contains('task_dependency_cycle'));
    expect(migration, contains('trail_task_mismatch'));
    expect(migration, contains('mission_completion_requires_rpc'));
    expect(migration, contains('confirm_mission_outcome'));
    expect(migration, contains('required_tasks_incomplete'));
    expect(
      repository,
      contains("client.rpc(\n      'confirm_mission_outcome'"),
    );
    expect(deleteFix, contains('new.mission_id := null'));
    expect(deleteFix, contains('new.task_id := null'));
    expect(allRolesGuard, isNot(contains("hierarchy_role <> 'outcome'")));
  });
}
