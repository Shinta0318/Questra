import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repositoryRoot = Directory.current.parent.parent;

  test('QST-338 and later separate canonical status from evidence state', () {
    final backlog = File(
      '${repositoryRoot.path}/docs/qst/BACKLOG.yaml',
    ).readAsLinesSync();
    const statuses = {
      'Planned',
      'InProgress',
      'Implemented',
      'Validated',
      'Completed',
      'Blocked',
      'Superseded',
    };
    const evidenceStates = {
      'not_started',
      'local_partial',
      'local_verified',
      'external_pending',
      'external_partial',
      'external_verified',
      'human_approval_pending',
      'human_approved',
      'not_required',
    };

    var qstNumber = 0;
    var checked = 0;
    for (var index = 0; index < backlog.length; index++) {
      final match = RegExp(r'^  - id: QST-(\d+)$').firstMatch(backlog[index]);
      if (match == null) continue;
      qstNumber = int.parse(match.group(1)!);
      if (qstNumber < 338) continue;

      final entry = backlog
          .skip(index + 1)
          .takeWhile((line) => !line.startsWith('  - id: QST-'));
      final status = entry
          .firstWhere((line) => line.startsWith('    status: '))
          .substring('    status: '.length);
      final evidence = entry
          .firstWhere((line) => line.startsWith('    evidence_state: '))
          .substring('    evidence_state: '.length);

      expect(statuses, contains(status), reason: 'QST-$qstNumber status');
      expect(
        evidenceStates,
        contains(evidence),
        reason: 'QST-$qstNumber evidence',
      );
      checked++;
    }
    expect(checked, greaterThanOrEqualTo(90));
  });

  test('normalizer supports drift check mode', () {
    final normalizer = File(
      '${repositoryRoot.path}/tools/qst/normalize_backlog_statuses.dart',
    ).readAsStringSync();
    expect(normalizer, contains("arguments.contains('--check')"));
    expect(normalizer, contains('evidence_state:'));
  });
}
