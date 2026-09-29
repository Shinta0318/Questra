import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = Directory.current.parent.parent;
  final migration = File(
    '${repo.path}/supabase/migrations/'
    '202609150004_tool_continuation_cost_attribution.sql',
  ).readAsStringSync();
  final admission = File(
    '${repo.path}/supabase/functions/_shared/quest_planning/'
    'ai_budget_admission.ts',
  ).readAsStringSync();
  final orchestrator = File(
    '${repo.path}/supabase/functions/_shared/quest_planning/'
    'tool_interaction_orchestrator.ts',
  ).readAsStringSync();
  final providerTest = File(
    '${repo.path}/supabase/functions/_shared/quest_planning/'
    'tool_interaction_orchestrator_test.ts',
  ).readAsStringSync();
  final runbook = File(
    '${repo.path}/docs/product/tool_continuation_cost_attribution.md',
  ).readAsStringSync();

  test(
    'every provider turn is recorded and exact aggregate usage is finalized',
    () {
      expect(orchestrator, contains('recordAiToolContinuationTurn'));
      expect(orchestrator, contains('mergeUsage(usage, response.usage)'));
      expect(orchestrator, contains('finalizeAiToolContinuationAttribution'));
      expect(migration, contains('ai_tool_continuation_total_mismatch'));
      expect(migration, contains('sum(turn_record.input_tokens)'));
      expect(migration, contains('sum(turn_record.output_tokens)'));
    },
  );

  test('fallback model route remains attributable per turn', () {
    expect(admission, contains('p_attempted_models: attemptedModels'));
    expect(migration, contains('attempted_models text[] not null'));
    expect(
      migration,
      contains(
        'attempted_models[cardinality(attempted_models)] = settled_model',
      ),
    );
    expect(
      providerTest,
      contains(
        'provider-backed multi-turn fallback finalizes exact aggregate cost attribution',
      ),
    );
  });

  test('cost evidence excludes prompt response and tool result bodies', () {
    for (final forbiddenColumn in <String>[
      'prompt',
      'response_body',
      'tool_result',
      'interaction_history',
    ]) {
      expect(migration, isNot(contains('$forbiddenColumn text')));
      expect(migration, isNot(contains('$forbiddenColumn jsonb')));
    }
    expect(
      providerTest,
      contains('private-tool-result-must-not-enter-cost-ledger'),
    );
    expect(runbook, contains('本文を保存しない'));
  });

  test(
    'timeout cancellation and duplicate continuation close idempotently',
    () {
      expect(orchestrator, contains('failureReason(response)'));
      expect(orchestrator, contains('Repeated tool call cycle detected'));
      expect(migration, contains("p_reason = 'cancelled'"));
      expect(migration, contains("v_run.status in ('failed', 'cancelled')"));
      expect(migration, contains("'idempotent', true"));
      expect(migration, contains('ai_tool_continuation_turn_conflict'));
    },
  );

  test('five total turns align between orchestrator and database ledger', () {
    expect(orchestrator, contains('bounded(options.maxTurns, 3, 1, 5)'));
    expect(orchestrator, contains('turn >= maxTurns'));
    expect(migration, contains('turn_number between 0 and 4'));
    expect(migration, contains('turn_count between 0 and 5'));
  });

  test('rollout is server-side gated and hosted drill is explicit', () {
    expect(admission, contains('AI_TOOL_CONTINUATION_ATTRIBUTION_ENABLED'));
    expect(runbook, contains('Hosted drill'));
    expect(runbook, contains('AI_TOOL_CONTINUATION_ATTRIBUTION_ENABLED=true'));
    expect(runbook, contains('ロールバック'));
  });
}
