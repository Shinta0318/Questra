import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
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
      expect(guide.missionCandidates, hasLength(greaterThanOrEqualTo(3)));
      expect(
        guide.missionCandidates.map((candidate) => candidate.guideType),
        containsAll([GuideType.route, GuideType.knowledge, GuideType.training]),
      );
      expect(
        guide.missionCandidates.map((candidate) => candidate.difficulty),
        everyElement(MissionDifficulty.easy),
      );
    },
  );
}
