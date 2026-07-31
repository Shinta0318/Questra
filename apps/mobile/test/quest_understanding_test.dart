import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/quest_understanding.dart';

void main() {
  test('Quest Understanding separates assumptions from known constraints', () {
    final understanding = QuestUnderstanding(
      originalWish: 'シンガポールへ行きたい',
      questOutcome: '安全に旅行を実現する',
      successEvidence: '旅程を終えてTrailを残す',
      motivation: '現地の文化に触れたい',
      currentState: '初めての海外旅行',
      constraints: const ['予算は未確認'],
      knownResources: const [],
      unknowns: const ['出発日'],
      planningRisks: const ['入国条件の更新'],
      planningMode: QuestPlanningMode.project,
      assumptions: const ['期限は未定として初期案を作る'],
    );

    expect(understanding.toJson()['planning_mode'], 'project');
    expect(understanding.toJson()['assumptions'], isNotEmpty);
    expect(understanding.toJson()['constraints'], isNotEmpty);
  });
}
