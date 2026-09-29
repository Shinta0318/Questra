import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = Directory.current.parent.parent;
  final migration = File(
    '${repo.path}/supabase/migrations/'
    '202609150005_approval_safe_ai_route_replacement.sql',
  ).readAsStringSync();
  final edge = File(
    '${repo.path}/supabase/functions/quest-planning-v2/index.ts',
  ).readAsStringSync();
  final pipeline = File(
    '${repo.path}/supabase/functions/_shared/quest_planning/pipeline.ts',
  ).readAsStringSync();
  final prompts = File(
    '${repo.path}/supabase/functions/_shared/quest_planning/'
    'prompt_registry.ts',
  ).readAsStringSync();
  final screen = File(
    '${repo.path}/apps/mobile/lib/features/quest/quest_detail_screen.dart',
  ).readAsStringSync();
  final taskRepository = File(
    '${repo.path}/apps/mobile/lib/features/task/task_repository.dart',
  ).readAsStringSync();
  final workspace = File(
    '${repo.path}/apps/mobile/lib/features/quest_journey/'
    'quest_journey_workspace.dart',
  ).readAsStringSync();

  test('planning carries existing route context through generation', () {
    expect(edge, contains('loadExistingRouteContext'));
    expect(edge, contains('buildExistingRouteContext'));
    expect(edge, contains('route_state=neq.removed'));
    expect(edge, contains('limit=31'));
    expect(edge, contains('if (rows.length > 30) return null'));
    expect(pipeline, contains('existingRoute?: Record<string, unknown>'));
    expect(pipeline, contains('routeApplication: input.existingRoute'));
    expect(
      prompts,
      contains('existingRoute.applicationMode is replace_remaining'),
    );
    expect(
      prompts,
      contains(
        'never emit, paraphrase, or invalidate a completed existing Mission',
      ),
    );
  });

  test('approval is stale-safe and preserves completed Missions', () {
    expect(
      migration,
      contains("raise exception 'route_changed_since_preview'"),
    );
    expect(migration, contains('v_application_mode is null'));
    expect(migration, contains("status <> 'completed'"));
    expect(migration, contains("status = 'completed'"));
    expect(migration, contains('route_id = v_route_id'));
    expect(migration, contains('for update'));
    expect(migration, isNot(contains('delete from public.missions')));
  });

  test('completed outcomes cannot be duplicated by an AI plan', () {
    expect(migration, contains('completed_mission_duplicate_in_plan'));
    expect(migration, contains('lower(btrim(title))'));
    expect(migration, contains('lower(btrim(v_mission->>\'title\'))'));
  });

  test('UI explains replacement before explicit approval', () {
    expect(screen, contains('AIで残りの航路を作る'));
    expect(screen, contains('残りの航路を更新しますか？'));
    expect(screen, contains('完了済みMission'));
    expect(screen, contains('この航路に更新'));
    expect(screen, contains('確定前は現在の航路に影響しません'));
    expect(screen, contains('hasActiveArcGuide'));
    expect(workspace, contains('AIで残りの航路を作る'));
    expect(workspace, contains('onPressed: onAskArcForMission'));
  });

  test('Tasks from replaced Missions do not return to active surfaces', () {
    expect(taskRepository, contains(".neq('missions.route_state', 'removed')"));
  });
}
