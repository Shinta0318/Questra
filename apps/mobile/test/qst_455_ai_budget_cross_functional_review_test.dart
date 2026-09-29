import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root =
      Directory.current.path.endsWith('apps${Platform.pathSeparator}mobile')
      ? Directory.current.parent.parent
      : Directory.current;

  String read(String path) => File('${root.path}/$path').readAsStringSync();

  String qstSection(String backlog, String id, {String? nextId}) {
    final start = backlog.indexOf('  - id: $id');
    expect(start, isNonNegative, reason: '$id must exist in the backlog');
    final end = nextId == null
        ? backlog.length
        : backlog.indexOf('  - id: $nextId', start + 1);
    return backlog.substring(start, end < 0 ? backlog.length : end);
  }

  test('hosted closure depends on local integrity work without a cycle', () {
    final backlog = read('docs/qst/BACKLOG.yaml');
    final qst447 = qstSection(backlog, 'QST-447', nextId: 'QST-448');
    final qst454 = qstSection(backlog, 'QST-454', nextId: 'QST-455');

    expect(qst447, contains('status: Planned'));
    expect(qst447, contains('evidence_state: external_pending'));
    expect(qst447, contains('QST-453'));
    expect(qst447, contains('QST-454'));
    expect(qst454, isNot(contains('depends_on: [QST-446, QST-447')));
  });

  test('review keeps external beta closed and records missing evidence', () {
    final report = read('reports/qst/QST-455.md');
    final hostedPlan = read('reports/qst/QST-447.md');
    final externalGate = read('docs/qst/EXTERNAL_BETA_GO_NO_GO.yaml');

    expect(report, contains('External Betaは`NO-GO`'));
    expect(report, contains('実画面確認済みとは扱わない'));
    expect(hostedPlan, contains('Planned / external evidence pending'));
    expect(externalGate, contains('decision: no_go'));
  });

  test(
    'tabletop finding becomes a non-duplicated compensating correction QST',
    () {
      final backlog = read('docs/qst/BACKLOG.yaml');
      final qst458 = qstSection(backlog, 'QST-458');

      expect(qst458, contains('Immutable Compensating AI Budget Correction'));
      expect(qst458, contains('適用済み補正requestとaudit recordを更新または削除しない'));
      expect(qst458, contains('request作成だけではcounterを変更せず'));
      expect(qst458, contains('blocks: [QST-447]'));
    },
  );
}
