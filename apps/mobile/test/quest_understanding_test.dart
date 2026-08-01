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

  test(
    'confirmed Success Contract increments without changing original wish',
    () {
      final original = QuestUnderstanding(
        originalWish: '本を書きたい',
        questOutcome: '原稿を完成させる',
        successEvidence: '原稿が保存されている',
        motivation: '',
        currentState: '',
        constraints: const [],
        knownResources: const [],
        unknowns: const [],
        planningRisks: const [],
        planningMode: QuestPlanningMode.project,
        assumptions: const ['形式は未定'],
      );
      final confirmed = original.copyWith(
        successEvidence: '全10章の原稿が保存されている',
        version: original.version + 1,
      );
      expect(confirmed.originalWish, original.originalWish);
      expect(confirmed.version, 2);
      expect(confirmed.successEvidence, contains('10章'));
    },
  );

  test('Quest Understanding survives a persistence round trip', () {
    final original = QuestUnderstanding(
      originalWish: '本を出版したい',
      questOutcome: '原稿を完成させて出版する',
      successEvidence: '出版物を確認できる',
      motivation: '知識を届けたい',
      currentState: '構想段階',
      constraints: const ['週末中心'],
      knownResources: const ['構成メモ'],
      unknowns: const ['出版方法'],
      planningRisks: const ['執筆時間'],
      planningMode: QuestPlanningMode.project,
      assumptions: const ['商業出版と自主出版を比較する'],
    );

    final restored = QuestUnderstanding.fromJson(original.toJson());

    expect(restored, isNotNull);
    expect(restored!.successEvidence, original.successEvidence);
    expect(restored.constraints, original.constraints);
    expect(restored.planningMode, QuestPlanningMode.project);
  });
}
