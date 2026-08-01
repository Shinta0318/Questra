import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root =
      Directory.current.path.endsWith('${Platform.pathSeparator}mobile')
      ? Directory.current.parent.parent
      : Directory.current;

  String read(String path) => File('${root.path}/$path').readAsStringSync();

  test(
    'new Quest Planning uses Interactions and pinned stable model routing',
    () {
      final adapter = read(
        'supabase/functions/_shared/quest_planning/interactions_adapter.ts',
      );
      final models = read(
        'supabase/functions/_shared/quest_planning/model_registry.ts',
      );
      expect(adapter, contains('/v1/interactions'));
      expect(adapter, contains('store: false'));
      expect(models, contains('gemini-3.6-flash'));
      expect(models, contains('releaseType: "stable"'));
      expect(models, isNot(contains('gemini-flash-latest')));
    },
  );

  test(
    'pipeline separates understanding planning generation critic and repair',
    () {
      final pipeline = read(
        'supabase/functions/_shared/quest_planning/pipeline.ts',
      );
      final understanding = pipeline.indexOf('"quest_understanding"');
      final contract = pipeline.indexOf('"success_contract"');
      final strategy = pipeline.indexOf('"strategic_plan"');
      final generation = pipeline.indexOf('"route_mission_generation"');
      final critic = pipeline.indexOf('"mission_critic"');
      final repair = pipeline.indexOf('"route_mission_repair"');
      expect(understanding, lessThan(contract));
      expect(contract, lessThan(strategy));
      expect(strategy, lessThan(generation));
      expect(generation, lessThan(critic));
      expect(critic, lessThan(repair));
      expect(pipeline.indexOf('"task_generation"'), greaterThan(repair));
      expect(
        pipeline.indexOf('"task_critic"'),
        greaterThan(pipeline.indexOf('"task_generation"')),
      );
      expect(pipeline, contains('persistenceAllowed: false'));
    },
  );

  test(
    'structured contract validates dependencies and does not use fixed templates',
    () {
      final schemas = read(
        'supabase/functions/_shared/quest_planning/schemas.ts',
      );
      final validators = read(
        'supabase/functions/_shared/quest_planning/validators.ts',
      );
      final endpoint = read('supabase/functions/quest-planning-v2/index.ts');
      expect(schemas, contains('minItems: 1'));
      expect(schemas, contains('maxItems: 30'));
      expect(validators, contains('dependency_cycle'));
      expect(validators, contains('template_like'));
      expect(endpoint, isNot(contains('fallbackMission')));
      expect(endpoint, isNot(contains('固定テンプレート')));
    },
  );

  test('approval is transactional and owner scoped', () {
    final migration = read(
      'supabase/migrations/202608010022_quest_mission_task_hierarchy.sql',
    );
    expect(migration, contains('approve_quest_plan_preview'));
    expect(migration, contains('for update'));
    expect(migration, contains('v_preview.owner_id <> auth.uid()'));
    expect(migration, contains("v_preview.status = 'approved'"));
    expect(
      migration,
      contains('grant execute on function public.approve_quest_plan_preview'),
    );
  });

  test(
    'grounding and tools keep personal data behind server authorization',
    () {
      final grounding = read(
        'supabase/functions/_shared/quest_planning/grounding.ts',
      );
      final tools = read(
        'supabase/functions/_shared/quest_planning/tool_server.ts',
      );
      expect(grounding, contains('sanitizeQueryIntent'));
      expect(tools, contains('ownsQuest'));
      expect(tools, contains('target_not_owned'));
      expect(tools, contains('ai_tool_audit_logs'));
      expect(tools, contains('redact'));
      final endpoint = read('supabase/functions/quest-planning-tools/index.ts');
      expect(endpoint, contains('authenticatedUserId'));
      expect(endpoint, contains('approved: false'));
    },
  );

  test(
    'release gate requires 200 provider-backed cases and zero safety violations',
    () {
      final gate = read('tools/qst/quest_planning_release_gate.ps1');
      expect(gate, contains('At least 200 evaluation cases'));
      expect(gate, contains('provider_backed_rate'));
      expect(gate, contains('critical_safety_violation'));
      expect(gate, contains('schema_success_rate'));
    },
  );
}
