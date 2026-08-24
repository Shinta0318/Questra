import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root =
      Directory.current.path.endsWith('${Platform.pathSeparator}mobile')
      ? Directory.current.parent.parent
      : Directory.current;

  String read(String path) => File('${root.path}/$path').readAsStringSync();

  test(
    'provider validates complete JSON schema locally before returning output',
    () {
      final adapter = read(
        'supabase/functions/_shared/quest_planning/interactions_adapter.ts',
      );
      final validator = read(
        'supabase/functions/_shared/quest_planning/json_schema_validator.ts',
      );
      expect(
        adapter,
        contains('validateJsonSchema(output, request.responseSchema)'),
      );
      expect(adapter, contains('"schema_invalid"'));
      expect(validator, contains('schema.additionalProperties === false'));
      expect(validator, contains('schema.minItems'));
      expect(validator, contains('schema.maxLength'));
    },
  );

  test('Mission and Task repair outputs are independently re-criticized', () {
    final pipeline = read(
      'supabase/functions/_shared/quest_planning/pipeline.ts',
    );
    expect(pipeline, contains('evaluationStage: "after_repair"'));
    expect(pipeline, contains('missionQualityGateIssues(plan, quality)'));
    expect(pipeline, contains('critic_result_missing'));
    expect(pipeline, contains('task_critic_rejected'));
    expect(pipeline, contains('maxRepairPasses: 1'));
  });

  test('approval revalidates selected Missions and recalculates Tasks', () {
    final endpoint = read('supabase/functions/quest-planning-v2/index.ts');
    final pipeline = read(
      'supabase/functions/_shared/quest_planning/pipeline.ts',
    );
    expect(endpoint, contains('revalidateApprovedMissionPlan'));
    expect(endpoint, contains('approved_selection_contains_unknown_mission'));
    expect(endpoint, contains('selectionRevalidationTraceId'));
    expect(pipeline, contains('approved_subset_final_validation'));
    expect(pipeline, contains('runTaskExpansionPipeline'));
  });

  test(
    'grounded plans require traceable sources and per-Mission references',
    () {
      final grounding = read(
        'supabase/functions/_shared/quest_planning/grounding.ts',
      );
      final schemas = read(
        'supabase/functions/_shared/quest_planning/schemas.ts',
      );
      expect(grounding, contains('grounding_source_missing'));
      expect(grounding, contains('grounded_claim_unlinked'));
      expect(grounding, contains('grounding_source_unknown'));
      expect(schemas, contains('groundedFactRefs'));
    },
  );

  test('database rejects approval without complete quality evidence', () {
    final migration = read(
      'supabase/migrations/202608240001_ai_planning_fail_closed_gate.sql',
    );
    expect(migration, contains('enforce_quest_plan_quality_gate'));
    expect(migration, contains('planning_quality_gate_missing'));
    expect(migration, contains('mission_critic_results_incomplete'));
    expect(migration, contains('task_critic_results_incomplete'));
    expect(migration, contains('before update of status'));
  });

  test('Flutter rejects incomplete server quality evidence', () {
    final guide = read(
      'apps/mobile/lib/features/quest/arc_quest_guide_service.dart',
    );
    final tasks = read(
      'apps/mobile/lib/features/task/task_generation_service.dart',
    );
    expect(guide, contains("qualityGate['status'] != 'passed'"));
    expect(guide, contains('_criticReviewPassed'));
    expect(
      guide,
      contains("criticVerdict: review?['verdict'] as String? ?? 'reject'"),
    );
    expect(tasks, contains("qualityGate['version'] != 'qst-341-v1'"));
    expect(tasks, contains('passedIds.length != suggestions.length'));
  });
}
