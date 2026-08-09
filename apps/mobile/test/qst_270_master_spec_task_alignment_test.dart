import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final masterSpec = File('../../docs/QUESTRA_MASTER_SPEC_V2.md');
  final domainSpec = File(
    '../../docs/architecture/quest-mission-task-trail.md',
  );
  final designBible = File('../../docs/product/DESIGN_BIBLE_V2.md');

  test('Task is an official term with one Mission owner', () {
    final master = masterSpec.readAsStringSync();
    final domain = domainSpec.readAsStringSync();

    expect(master, contains('| Task |'));
    expect(master, contains('Taskは、1つのMissionに属する'));
    expect(domain, contains('Every Task belongs'));
    expect(domain, contains('MISSIONS ||--|{ TASKS'));
  });

  test('Mission and Task responsibilities remain distinct', () {
    final canonicalDocuments = <String>[
      masterSpec.readAsStringSync(),
      domainSpec.readAsStringSync(),
      designBible.readAsStringSync(),
    ];

    for (final content in canonicalDocuments) {
      expect(content, isNot(contains('Mission: a concrete action')));
      expect(content, isNot(contains('Missionは、Questを今日または近い将来に進める具体行動')));
    }

    expect(canonicalDocuments[0], contains('Missionは、Questを前進させる検証可能な中間成果'));
    expect(
      canonicalDocuments[2],
      contains('Task is the smallest concrete action'),
    );
  });

  test('Mission completion requires explicit outcome confirmation', () {
    final master = masterSpec.readAsStringSync();
    final domain = domainSpec.readAsStringSync();

    expect(master, contains('Task完了だけでMissionやQuestを'));
    expect(master, contains('連鎖的に自動完了してはならない'));
    expect(domain, contains('does not complete the Mission'));
  });

  test('legacy concrete Missions have a non-destructive migration rule', () {
    final master = masterSpec.readAsStringSync();
    final domain = domainSpec.readAsStringSync();

    expect(master, contains('### 11.6 既存データの移行規則'));
    expect(master, contains('直ちに削除・上書きしない'));
    expect(domain, contains('## Legacy Migration Policy'));
  });
}
