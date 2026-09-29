import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = Directory.current.parent.parent;
  final migration = File(
    '${repo.path}/supabase/migrations/'
    '202609150001_ai_cost_anomaly_detection.sql',
  ).readAsStringSync();
  final admission = File(
    '${repo.path}/supabase/functions/_shared/quest_planning/'
    'ai_budget_admission.ts',
  ).readAsStringSync();
  final runbook = File(
    '${repo.path}/docs/product/ai_cost_anomaly_detection.md',
  ).readAsStringSync();

  test('actual cost is grouped by operation model thinking and grounding', () {
    expect(migration, contains('create or replace view public.ai_cost_observations_daily'));
    for (final dimension in <String>[
      'base.operation',
      'base.model_name',
      'receipt.thinking_level',
      'used_grounding',
      'token_cost_micros',
      'grounding_cost_micros',
      'total_cost_micros',
    ]) {
      expect(migration, contains(dimension));
    }
    expect(admission, contains('record_ai_provider_execution_receipt_v3'));
    expect(admission, contains('p_thinking_level: response.thinkingLevel'));
    expect(migration, contains('ai_provider_thinking_evidence_required'));
  });

  test('baseline detection is aggregate bounded and idempotent', () {
    expect(migration, contains('baseline_days between 3 and 30'));
    expect(migration, contains('minimum_history_days'));
    expect(migration, contains('increase_multiplier'));
    expect(migration, contains('minimum_cost_delta_micros'));
    expect(migration, contains('p_observation_day < current_date - 90'));
    expect(migration, contains('on conflict do nothing'));
    expect(migration, contains("'alerts_created', v_created"));
  });

  test('anomaly detection cannot automatically change product access', () {
    final start = migration.indexOf(
      'create or replace function public.detect_ai_cost_anomalies',
    );
    final end = migration.indexOf(
      'create or replace function public.resolve_ai_cost_anomaly',
    );
    final detector = migration.substring(start, end);
    expect(detector, isNot(contains('update public.ai_operation_controls')));
    expect(detector, isNot(contains('subscription')));
    expect(detector, isNot(contains('entitlement')));
    expect(detector, isNot(contains('premium')));
  });

  test('alerts and controls keep a bounded operator audit trail', () {
    expect(migration, contains('create table if not exists public.ai_cost_anomaly_alerts'));
    expect(migration, contains("'false_positive'"));
    expect(migration, contains("'recovered'"));
    expect(migration, contains('create table if not exists public.ai_operation_control_audit'));
    expect(migration, contains('create or replace function public.set_ai_operation_control'));
    expect(migration, contains("'cost_anomaly_confirmed'"));
    expect(migration, contains("'operator_recovery'"));
  });

  test('aggregate alert storage excludes journey and conversation content', () {
    final start = migration.indexOf(
      'create table if not exists public.ai_cost_anomaly_alerts',
    );
    final end = migration.indexOf(
      'create index if not exists ai_cost_anomaly_alerts_status_day_idx',
    );
    final alertTable = migration.substring(start, end);
    for (final forbidden in <String>[
      'user_id',
      'owner_id',
      'quest_id',
      'mission_id',
      'trace_id',
      'prompt',
      'response',
      'provider_interaction_id',
    ]) {
      expect(alertTable, isNot(contains(forbidden)));
    }
  });

  test('operator surfaces are server-only and runbook is fail-safe', () {
    expect(migration, contains('from public, anon, authenticated'));
    expect(migration, contains('to service_role'));
    expect(runbook, contains('自動停止しない'));
    expect(runbook, contains('利用者の課金・Premium・権利'));
    expect(runbook, contains('誤検知'));
    expect(runbook, contains('Hosted Supabase'));
  });
}
