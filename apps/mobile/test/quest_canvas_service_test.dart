import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_canvas_service.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/trail/trail_model.dart';

void main() {
  test('Quest Canvas derives growth without duplicating source entities', () {
    final quest = Quest(
      id: 'quest-1',
      title: '富士山に登る',
      description: '',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
    );
    final missions = [
      Mission(
        id: 'mission-1',
        questId: quest.id,
        questTitle: quest.title,
        title: '登山靴を比較する',
        description: '',
        guideType: GuideType.knowledge,
        difficulty: MissionDifficulty.easy,
        status: MissionStatus.completed,
        category: '装備',
        referenceHints: const ['official guide'],
        enterpriseSupportHints: const ['outdoor shop'],
      ),
      Mission(
        id: 'mission-2',
        questId: quest.id,
        questTitle: quest.title,
        title: '安全な登山計画を作る',
        description: '',
        guideType: GuideType.route,
        difficulty: MissionDifficulty.normal,
        status: MissionStatus.todo,
        priority: MissionPriority.critical,
      ),
    ];
    final trails = [
      Trail(
        questId: quest.id,
        title: '装備の条件を整理',
        summary: '',
        content: '',
        trailType: TrailType.questRecord,
      ),
    ];

    final snapshot = QuestCanvasService.build(
      quest: quest,
      missions: missions,
      trails: trails,
    );

    expect(snapshot.missionCount, 2);
    expect(snapshot.completedMissionCount, 1);
    expect(snapshot.knowledgeCount, 1);
    expect(snapshot.skillThemes, ['装備']);
    expect(snapshot.riskCount, 1);
    expect(snapshot.supportHintCount, 1);
    expect(snapshot.trailCount, 1);
    expect(snapshot.quest, same(quest));
  });
}
