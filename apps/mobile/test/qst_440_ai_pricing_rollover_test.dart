import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = Directory.current.parent.parent;
  final migration = File(
    '${repo.path}/supabase/migrations/'
    '202609130001_ai_pricing_effective_date_rollover.sql',
  ).readAsStringSync();

  test('Gemini 3.6 pricing changes at the documented UTC boundary', () {
    expect(migration, contains("timestamptz '2027-01-01 00:00:00+00'"));
    expect(migration, contains('1500000'));
    expect(migration, contains('7500000'));
    expect(
      migration,
      contains('https://ai.google.dev/gemini-api/docs/pricing'),
    );
    expect(migration, contains("date '2026-09-13'"));
    expect(migration, contains("default 'USD'"));
    expect(migration, contains("'micros_per_million_tokens'"));
  });

  test('rate windows reject overlap and expose a gap verifier', () {
    expect(migration, contains('ai_model_cost_rates_no_overlap'));
    expect(migration, contains('exclude using gist'));
    expect(migration, contains('verify_ai_model_cost_rate_windows'));
    expect(migration, contains('previous_valid_until is distinct from'));
    expect(migration, contains('reverse_sequence_number = 1'));
    expect(migration, contains('ai_model_cost_rate_window_gap_or_overlap'));
  });

  test('effective rates are immutable after activation', () {
    expect(migration, contains('protect_ai_model_cost_rate_history'));
    expect(migration, contains('old.effective_from <= now()'));
    expect(migration, contains('effective_ai_model_cost_rate_is_immutable'));
    expect(
      migration,
      contains('effective_ai_model_cost_rate_window_is_immutable'),
    );
  });

  test('reservation snapshots survive a later pricing rollover', () {
    expect(migration, contains('pricing_effective_at'));
    expect(migration, contains('reserved_rate_effective_from'));
    expect(migration, contains('reserved_input_rate_micros'));
    expect(migration, contains('reserved_output_rate_micros'));
    expect(migration, contains('populate_ai_reservation_price_snapshot'));
    expect(migration, contains('effective_from <= v_row.pricing_effective_at'));
    expect(migration, contains('valid_until > v_row.pricing_effective_at'));
    expect(migration, contains('actual_rate_effective_from'));
    expect(
      migration,
      isNot(
        contains(
          'v_cost := public.ai_token_cost_micros(\n'
          '    v_row.provider, p_model_name',
        ),
      ),
    );
  });

  test('pricing and settlement functions remain server-only', () {
    expect(
      migration,
      contains('revoke all on function public.ai_token_cost_micros_at('),
    );
    expect(
      migration,
      contains('revoke all on function public.settle_ai_usage_budget('),
    );
    expect(migration, contains('to service_role;'));
  });
}
