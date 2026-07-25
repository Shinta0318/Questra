import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_contract_service.dart';
import 'package:questra/features/mission/mission_plan_draft.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/arc_quest_guide_service.dart';
import 'package:questra/features/quest/quest_guide_model.dart';

void main() {
  const contract = MissionContractService();

  test('Quest title cannot also be used as its Mission title', () {
    expect(
      contract.validateTitle(
        questTitle: 'シンガポールへ行く',
        missionTitle: ' シンガポールへ行く。 ',
      ),
      contains('Questと同じ名前'),
    );
  });

  test('duplicate Mission title under one Quest is rejected', () {
    expect(
      contract.validateTitle(
        questTitle: 'シンガポールへ行く',
        missionTitle: '旅券を確認する',
        existingTitles: const ['旅券を確認する'],
      ),
      contains('同名のMission'),
    );
  });

  test('generated plan repairs Quest-title candidate and removes duplicates',
      () {
    final guide = ArcQuestGuide(
      questId: 'quest-1',
      summary: 'summary',
      path: 'path',
      cautions: 'cautions',
      encouragement: 'encouragement',
      sourceType: 'test',
      missionCandidates: const [
        ArcMissionCandidate(
          title: 'シンガポールへ行く',
          description: '完了条件を決めたら完了です。',
          guideType: GuideType.route,
          difficulty: MissionDifficulty.easy,
        ),
        ArcMissionCandidate(
          title: '旅券を確認する',
          description: '有効期限を確認したら完了です。',
          guideType: GuideType.knowledge,
          difficulty: MissionDifficulty.easy,
        ),
        ArcMissionCandidate(
          title: '旅券を確認する',
          description: '同じ候補です。',
          guideType: GuideType.knowledge,
          difficulty: MissionDifficulty.easy,
        ),
      ],
    );

    final draft = MissionPlanDraft.fromArcGuide(
      guide,
      questTitle: 'シンガポールへ行く',
    );

    expect(draft.candidates, hasLength(2));
    expect(draft.candidates.first.title, '達成条件を一文で決める');
    expect(draft.candidates.last.title, '旅券を確認する');
  });
}
