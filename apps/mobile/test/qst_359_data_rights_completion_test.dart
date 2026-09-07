import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '../../supabase/migrations/202608250004_data_rights_correction_and_withdrawal.sql',
  ).readAsStringSync();

  test('personal sharing requires context to grant but can be withdrawn', () {
    expect(
      migration,
      contains("p_purpose_code = 'personal_data_sharing' and p_granted"),
    );
    expect(
      migration,
      contains("'business_recommendations', 'personal_data_sharing'"),
    );
  });

  test('correction scope is allowlisted and bounded server-side', () {
    expect(
      migration,
      contains("('profile', 'arc_memory', 'quest_dna', 'tag')"),
    );
    expect(migration, contains('length(v_requested_change) > 500'));
    expect(migration, contains("p_request_type = 'correction'"));
  });

  test('account deletion scope cannot be supplied by the client', () {
    expect(migration, contains("jsonb_build_array('legal', 'security_audit')"));
  });
}
