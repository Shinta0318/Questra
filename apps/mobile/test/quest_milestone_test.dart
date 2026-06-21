import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_milestone_model.dart';
import 'package:questra/features/quest/quest_milestone_repository.dart';
import 'package:questra/features/quest/quest_milestone_service.dart';
import 'package:questra/features/quest/quest_model.dart';

void main() {
  test('milestone service creates a Quest planning path', () {
    final quest = Quest(
      title: '富士山に登る',
      description: '夏までに安全に登頂する',
      difficulty: QuestDifficulty.hard,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
      progress: 0.3,
      category: '挑戦',
    );
    final service = QuestMilestoneService();

    final milestones = service.plan(
      quest: quest,
      guides: [
        QuestGuide(
          questId: quest.id,
          guideType: GuideType.route,
          title: 'Route',
          description: '航路',
          suggestedActions: const ['到達点を決める'],
        ),
      ],
      missions: [
        Mission(
          questId: quest.id,
          questTitle: quest.title,
          title: '登山靴を確認する',
          description: '装備を確認する',
          guideType: GuideType.training,
          difficulty: MissionDifficulty.easy,
          status: MissionStatus.completed,
        ),
      ],
    );

    expect(milestones, hasLength(3));
    expect(milestones.first.status, QuestMilestoneStatus.completed);
    expect(milestones[1].title, contains('Mission'));
    expect(milestones[2].progress, 1);
  });

  test('milestone repository returns sorted Quest milestones', () async {
    final repository = InMemoryQuestMilestoneRepository();
    final second = QuestMilestone(
      questId: 'quest-1',
      title: 'Second',
      description: 'second',
      status: QuestMilestoneStatus.active,
      progress: 0.5,
      sortOrder: 1,
    );
    final first = QuestMilestone(
      questId: 'quest-1',
      title: 'First',
      description: 'first',
      status: QuestMilestoneStatus.completed,
      progress: 1,
      sortOrder: 0,
    );

    await repository.save(ownerId: 'user-1', milestone: second);
    await repository.save(ownerId: 'user-1', milestone: first);

    final milestones = await repository.findByQuestIds(['quest-1']);

    expect(milestones.map((milestone) => milestone.title), ['First', 'Second']);
  });

  test('milestone status cycles gently', () {
    const service = QuestMilestoneService();

    expect(
      service.nextStatus(QuestMilestoneStatus.planned),
      QuestMilestoneStatus.active,
    );
    expect(
      service.nextStatus(QuestMilestoneStatus.active),
      QuestMilestoneStatus.completed,
    );
    expect(
      service.nextStatus(QuestMilestoneStatus.completed),
      QuestMilestoneStatus.planned,
    );
  });
}
