import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/arc_quest_guide_service.dart';
import 'package:questra/features/quest/planning_context.dart';
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
      expect(guide.planQuality, isNotNull);
      expect(guide.planQuality!.generationVersion, contains('quest_guide_v3'));
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

  test(
    'local planning reflects explicitly consented weekly capacity',
    () async {
      const service = LocalArcQuestGuideService();
      final guide = await service.generate(
        quest: Quest(
          title: '新しい技術を学ぶ',
          description: '仕事の幅を広げたい',
          difficulty: QuestDifficulty.normal,
          status: QuestStatus.active,
          visibility: QuestVisibility.private,
          category: '学習',
        ),
        planningContext: const PlanningContext(
          weeklyMinutes: 90,
          experience: '初めて',
          consentGranted: true,
        ),
      );

      expect(guide.path, contains('週90分'));
      expect(
        guide.missionCandidates.map((item) => item.description).join(),
        contains('経験 初めて'),
      );
    },
  );
}
