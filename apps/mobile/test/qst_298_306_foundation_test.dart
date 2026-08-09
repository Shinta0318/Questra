import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Arc draft storage is owner partitioned, bounded and expiring', () {
    final source = File(
      'lib/features/arc/arc_journey_draft_repository.dart',
    ).readAsStringSync();
    expect(source, contains('base64Url.encode(utf8.encode(ownerId))'));
    expect(source, contains('Duration(days: 14)'));
    expect(source, contains('.take(40)'));
    expect(source, contains("row['ownerId'] != ownerId"));
  });

  test('Data Rights lifecycle is owner scoped and authenticated', () {
    final sql = File(
      '../../supabase/migrations/202608090003_data_rights_request_lifecycle.sql',
    ).readAsStringSync();
    expect(sql, contains('owner_id = auth.uid()'));
    expect(sql, contains('v_owner uuid := auth.uid()'));
    expect(sql, contains("'account_deletion'"));
    expect(sql, contains('grant execute on function'));
    expect(sql, contains('data_rights_audit_events'));
  });
}
