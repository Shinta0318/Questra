import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root =
      Directory.current.path.endsWith('apps${Platform.pathSeparator}mobile')
      ? Directory.current.parent.parent
      : Directory.current;

  String read(String path) => File('${root.path}/$path').readAsStringSync();

  late String migration;

  setUpAll(() {
    migration = read(
      'supabase/migrations/'
      '202609150006_immutable_compensating_ai_budget_correction.sql',
    );
  });

  test('compensation links to one applied request without rewriting it', () {
    expect(migration, contains('compensates_request_id uuid references'));
    expect(migration, contains('ai_budget_correction_one_compensation_idx'));
    expect(migration, contains("v_original.status <> 'applied'"));
    expect(
      migration,
      isNot(
        contains(
          'update public.ai_budget_correction_requests\n  set compensates_request_id',
        ),
      ),
    );
  });

  test('current snapshot must still match the applied correction', () {
    expect(migration, contains('for update;'));
    expect(migration, contains('v_original.corrected_model_name'));
    expect(migration, contains('v_original.corrected_input_tokens'));
    expect(migration, contains('v_original.corrected_output_tokens'));
    expect(migration, contains('v_original.corrected_cost_micros'));
    expect(migration, contains('budget_compensation_stale_snapshot'));
  });

  test('request creation is auth bound and cannot mutate usage counters', () {
    final requestStart = migration.indexOf(
      'create or replace function public.request_compensating_ai_budget_correction',
    );
    final wrapperStart = migration.indexOf(
      'create or replace function public.request_my_compensating_ai_budget_correction',
    );
    final requestFunction = migration.substring(requestStart, wrapperStart);

    expect(
      requestFunction,
      contains("assert_ai_reconciliation_operator(p_operator_id, 'reviewer')"),
    );
    expect(requestFunction, contains('active_operator_claim_required'));
    expect(requestFunction, contains("'pending_approval'"));
    expect(requestFunction, isNot(contains('update public.ai_usage_counters')));
    expect(
      migration,
      contains("current_ai_reconciliation_operator('reviewer')"),
    );
    expect(
      migration,
      contains('from public, anon, authenticated, service_role'),
    );
  });

  test('existing approval transaction remains the only apply path', () {
    expect(migration, contains("'compensating_correction'"));
    expect(migration, contains("'correction_requested'"));
    expect(
      migration,
      isNot(contains('create or replace function public.apply_compensating')),
    );
    expect(
      read(
        'supabase/migrations/202609130004_ai_budget_reconciliation_operator_queue.sql',
      ),
      contains('create or replace function public.apply_ai_budget_correction'),
    );
  });

  test('backlog keeps hosted PostgreSQL evidence pending', () {
    final backlog = read('docs/qst/BACKLOG.yaml');
    final start = backlog.indexOf('  - id: QST-458');
    final section = backlog.substring(start);

    expect(section, contains('status: Implemented'));
    expect(section, contains('evidence_state: external_pending'));
    expect(section, contains('blocks: [QST-447]'));
  });
}
