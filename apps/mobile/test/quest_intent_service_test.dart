import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/quest_intent_model.dart';
import 'package:questra/features/quest/quest_intent_service.dart';

void main() {
  test('literal impossible wish is reframed into an achievable meaning', () {
    final draft = QuestIntentService.frame(outcome: '過去に戻って人生を変えたい');
    expect(draft.realityFrame, QuestRealityFrame.symbolic);
    expect(draft.reframedOutcome, isNotEmpty);
    expect(draft.effectiveOutcome, isNot(equals(draft.outcome)));
  });

  test('ambitious harmless wish remains available for planning', () {
    final draft = QuestIntentService.frame(outcome: 'オリンピックに出場したい');
    expect(draft.realityFrame, QuestRealityFrame.ambitious);
    expect(draft.reframedOutcome, isNull);
  });

  test('motivation and observable condition are preserved', () {
    final draft = QuestIntentService.frame(
      outcome: '英語を話せるようになる',
      motivation: '海外の友人と話したい',
      successCondition: '英語で30分会話できる',
    );
    expect(draft.motivation, '海外の友人と話したい');
    expect(draft.successCondition, '英語で30分会話できる');
  });
}
