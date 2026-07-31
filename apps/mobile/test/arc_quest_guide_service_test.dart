import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/arc_quest_guide_service.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';

void main() {
  test(
    'local Arc Quest Guide creates mission candidates for a quest',
    () async {
      const service = LocalArcQuestGuideService();
      final quest = Quest(
        title: 'Questraをローンチする',
        description: 'Betaへ進めるためのMVPを整える',
        difficulty: QuestDifficulty.hard,
        status: QuestStatus.active,
        visibility: QuestVisibility.private,
        category: '起業',
      );

      final guide = await service.generate(quest: quest);

      expect(guide.questId, quest.id);
      expect(guide.summary, contains(quest.title));
      expect(guide.path, isNotEmpty);
      expect(guide.cautions, isNotEmpty);
      expect(guide.encouragement, contains('Arc'));
      expect(guide.missionCandidates, hasLength(4));
      expect(
        guide.missionCandidates.map((candidate) => candidate.guideType),
        containsAll([GuideType.route, GuideType.knowledge, GuideType.training]),
      );
      expect(
        guide.missionCandidates,
        everyElement(
          isA<ArcMissionCandidate>().having(
            (mission) => mission.doneCondition,
            'done condition',
            isNotEmpty,
          ),
        ),
      );
    },
  );

  test(
    'local fallback does not invent category-specific travel steps',
    () async {
      const service = LocalArcQuestGuideService();
      final guide = await service.generate(
        quest: Quest(
          title: 'シンガポールへ行く',
          description: '文化と食を楽しむ旅を実現したい',
          difficulty: QuestDifficulty.normal,
          status: QuestStatus.active,
          visibility: QuestVisibility.private,
          category: '旅行',
        ),
      );

      expect(guide.missionCandidates, hasLength(4));
      final titles = guide.missionCandidates.map((mission) => mission.title);
      expect(titles, contains('達成したと分かる状態を決める'));
      expect(titles, contains('最初に確認する情報源を決める'));
      expect(titles, isNot(contains('宿泊エリアと宿を比較する')));
      expect(
        guide.missionCandidates,
        everyElement(
          isA<ArcMissionCandidate>().having(
            (mission) => mission.description,
            'done condition',
            contains('完了です'),
          ),
        ),
      );
    },
  );
}
