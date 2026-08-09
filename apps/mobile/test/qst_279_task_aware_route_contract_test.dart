import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Task-aware route changes are transactional and rollback-safe', () {
    final root =
        Directory.current.path.endsWith('${Platform.pathSeparator}mobile')
        ? Directory.current.parent.parent
        : Directory.current;
    final migration = File(
      '${root.path}/supabase/migrations/202608080005_task_aware_route_replanning.sql',
    ).readAsStringSync();
    final model = File(
      '${root.path}/apps/mobile/lib/features/quest/route_replanning_model.dart',
    ).readAsStringSync();

    expect(model, contains('targetTaskId'));
    expect(migration, contains('target_task_id'));
    expect(migration, contains('completed_task_is_immutable'));
    expect(migration, contains('created_task_ids'));
    expect(migration, contains('rollback_task_aware_route_change_proposal'));
    expect(
      migration,
      contains("not (t.status='completed' and s.status <> 'completed')"),
    );
  });
}
