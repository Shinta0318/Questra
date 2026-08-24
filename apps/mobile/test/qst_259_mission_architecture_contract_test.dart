import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root =
      Directory.current.path.endsWith('${Platform.pathSeparator}mobile')
      ? Directory.current.parent.parent
      : Directory.current;

  String read(String path) => File('${root.path}/$path').readAsStringSync();

  test('Mission architecture runs before granularity coverage and critic', () {
    final pipeline = read(
      'supabase/functions/_shared/quest_planning/pipeline.ts',
    );
    final understanding = pipeline.indexOf('"quest_understanding"');
    final success = pipeline.indexOf('"success_contract"');
    final domains = pipeline.indexOf('"achievement_domain_analysis"');
    final architecture = pipeline.indexOf('"route_mission_generation"');
    final granularity = pipeline.indexOf('"mission_granularity_classifier"');
    final coverage = pipeline.indexOf('"mission_coverage_analysis"');
    final critic = pipeline.indexOf('"mission_critic"');
    expect(understanding, lessThan(success));
    expect(success, lessThan(domains));
    expect(domains, lessThan(architecture));
    expect(architecture, lessThan(granularity));
    expect(granularity, lessThan(coverage));
    expect(coverage, lessThan(critic));
    expect(pipeline, contains('repairPass <= 1'));
    expect(pipeline, contains('maxRepairPasses: 1'));
    expect(pipeline, contains('belowMissionThreshold'));
  });

  test('Mission output contract separates outcomes from Tasks', () {
    final schemas = read(
      'supabase/functions/_shared/quest_planning/schemas.ts',
    );
    final prompts = read(
      'supabase/functions/_shared/quest_planning/prompt_registry.ts',
    );
    final validators = read(
      'supabase/functions/_shared/quest_planning/validators.ts',
    );
    for (final field in [
      'reasonRequired',
      'coveredSuccessConditions',
      'parallelizable',
      'childTaskEstimate',
    ]) {
      expect(schemas, contains(field));
    }
    expect(schemas, contains('"task", "too_abstract", "duplicate"'));
    expect(prompts, contains("Questra's Mission Architect"));
    expect(prompts, contains('Do not use category templates'));
    expect(validators, contains('task_granularity'));
    expect(validators, contains('required_condition_unmapped'));
  });

  test('draft candidates remain separate until transactional approval', () {
    final migration = read(
      'supabase/migrations/202608010024_mission_architecture_quality.sql',
    );
    final approvalMigration = read(
      'supabase/migrations/202608010022_quest_mission_task_hierarchy.sql',
    );
    expect(
      migration,
      contains('create table if not exists public.mission_plan_drafts'),
    );
    expect(
      migration,
      contains('create table if not exists public.mission_candidates'),
    );
    expect(migration, contains('critic_scores jsonb'));
    expect(migration, contains('enable row level security'));
    expect(approvalMigration, contains('approve_quest_plan_preview'));
    expect(approvalMigration, contains('for update'));
    expect(approvalMigration, contains("v_preview.status = 'approved'"));
  });

  test('Flutter uses planning v2 without production template fallback', () {
    final service = read(
      'apps/mobile/lib/features/quest/arc_quest_guide_service.dart',
    );
    final detail = read(
      'apps/mobile/lib/features/quest/quest_detail_screen.dart',
    );
    expect(service, contains("'quest-planning-v2'"));
    expect(service, contains("'approved_missions'"));
    expect(service, contains('固定候補には置き換えず'));
    expect(detail, contains('approveForQuest'));
    expect(detail, contains('このMissionで達成すること'));
    expect(detail, contains('想定Task'));
  });
}
