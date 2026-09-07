import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '../../supabase/migrations/202608250006_trail_share_recipient_abuse_controls.sql',
  ).readAsStringSync();

  test('recipient resolution requires authentication and is rate limited', () {
    expect(migration, contains('v_recipient uuid := auth.uid()'));
    expect(migration, contains("raise exception 'authentication_required'"));
    expect(migration, contains('trail_share_access_buckets'));
    expect(migration, contains('if v_attempts > 30'));
  });

  test('unknown expired revoked and held links share one response', () {
    expect(
      migration,
      contains("jsonb_build_object('status', 'not_available')"),
    );
    expect(migration, contains('revoked_at is null'));
    expect(migration, contains('safety_hold_at is null'));
    expect(migration, contains('expires_at > now()'));
  });

  test('reports use reason codes and independent reporters trigger hold', () {
    expect(migration, contains('trail_share_abuse_reports'));
    expect(migration, contains('unique (link_id, reporter_id, reason_code)'));
    expect(migration, contains('if v_reports >= 3'));
    expect(migration, isNot(contains('report_detail')));
  });

  test('share creation blocks contact details on the server', () {
    expect(migration, contains('personal_contact_detected'));
    expect(migration, contains('v_selected_text'));
    expect(migration, contains('p_include_content'));
  });

  test('legacy anonymous resolver is no longer executable', () {
    expect(
      migration,
      contains(
        'revoke all on function public.resolve_trail_share_link(text) from anon, authenticated',
      ),
    );
    final router = File('lib/core/router/app_router.dart').readAsStringSync();
    expect(router, contains('TrailShareScreen'));
  });
}
