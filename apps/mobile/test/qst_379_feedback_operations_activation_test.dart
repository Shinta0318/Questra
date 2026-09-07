import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = Directory.current.parent.parent;

  test('feedback activation binds real operations data to current candidate', () {
    final tool = File(
      '${repo.path}/tools/qst/activate_beta_feedback_operations.dart',
    ).readAsStringSync();
    expect(tool, contains("values['candidate-commit'] != head"));
    expect(tool, contains("'channel-label'"));
    expect(tool, contains("'owner-ref'"));
    expect(tool, contains("'stop-channel-label'"));
    expect(tool, contains('_openCounts'));
    expect(tool, contains('_looksSensitive'));
  });

  test('pending operations evidence remains honest before activation', () {
    final operations = File(
      '${repo.path}/docs/qst/BETA_FEEDBACK_OPERATIONS.yaml',
    ).readAsStringSync();
    expect(operations, contains('status: activation_pending'));
    expect(operations, contains('stop_communication:'));
    expect(operations, contains('invented_operator_evidence_allowed: false'));
    expect(operations, contains('candidate_commit_mismatch_allowed: false'));
  });
}
