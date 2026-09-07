import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = Directory.current.parent.parent;

  test('provider evaluation requires clean SHA-bound hosted execution', () {
    final runner = File(
      '${repo.path}/tools/qst/run_provider_backed_ai_eval.ps1',
    ).readAsStringSync();
    expect(
      runner,
      contains(
        'Provider-backed evaluation requires a clean candidate worktree',
      ),
    );
    expect(runner, contains('quest-planning-v2'));
    expect(runner, contains('moderate-quest-intent'));
    expect(runner, contains('candidate_source_commit'));
    expect(runner, contains('input_tokens'));
    expect(runner, contains('output_tokens'));
    expect(runner, contains('estimated_cost_usd'));
    expect(runner, contains('InputUsdPerMillionTokens'));
    expect(runner, contains('OutputUsdPerMillionTokens'));
    expect(runner, contains('PricingVersion'));
    expect(runner, contains('thinking_levels'));
    expect(runner, contains('provider_trace_ids'));
    expect(runner, contains('non_fallback_source'));
    expect(runner, contains('AccountShardCount = 8'));
    expect(runner, contains('DelayMilliseconds = 2100'));
    expect(runner, contains(r'$caseIndex % $accounts.Count'));
    expect(
      runner,
      contains(
        'No evaluation evidence was written because cleanup did not complete',
      ),
    );
  });

  test(
    'release gate covers provider, schema, usage, latency, cost and safety',
    () {
      final gate = File(
        '${repo.path}/tools/qst/quest_planning_release_gate.ps1',
      ).readAsStringSync();
      for (final signal in [
        'provider_backed_rate',
        'schema_success_rate',
        'usage_coverage_rate',
        'p95_latency_ms',
        'total_cost_usd',
        'critical_safety_violation',
        'safety_expected_action_rate',
        'version_configuration_count',
        'safety_non_fallback_rate',
        'HumanReviewPath',
        'planning_review_count',
      ]) {
        expect(gate, contains(signal));
      }
      expect(
        gate,
        contains(
          r'provider_backed_rate=$($metrics.provider_backed_rate) < 100',
        ),
      );
    },
  );

  test('quest planning v2 enforces safety at its authenticated boundary', () {
    final endpoint = File(
      '${repo.path}/supabase/functions/quest-planning-v2/index.ts',
    ).readAsStringSync();
    expect(endpoint, contains('deterministicSafetyAssessment(wish)'));
    expect(endpoint, contains('unsafe_intent'));
    expect(endpoint, contains('status: 422'));
  });

  test(
    'provider evidence requires stratified human review on the same run',
    () {
      final recorder = File(
        '${repo.path}/tools/qst/record_provider_eval_human_review.dart',
      ).readAsStringSync() + File('${repo.path}/tools/qst/provider_review_contract.dart').readAsStringSync();
      final verifier = File(
        '${repo.path}/tools/qst/verify_provider_eval_run.dart',
      ).readAsStringSync();
      for (final signal in [
        'At least 40 planning cases require human review',
        'Every safety corpus case requires human review',
        'at least 10 categories and 10 personas',
        'planningPassRate >= 85',
        'reviewer_free_text_recorded',
      ]) {
        expect(recorder, contains(signal));
      }
      expect(verifier, contains('--require-verified'));
      expect(verifier, contains('human_review_sha256'));
    },
  );

  test('safety evaluation corpus covers block, reframe and allow', () {
    final corpus = File(
      '${repo.path}/tools/qst/quest_planning_safety_eval_cases.json',
    ).readAsStringSync();
    expect(RegExp(r'"id"').allMatches(corpus), hasLength(10));
    expect(corpus, contains('"expected_action":"block"'));
    expect(corpus, contains('"expected_action":"reframe"'));
    expect(corpus, contains('"expected_action":"allow"'));
  });
}
