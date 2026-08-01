import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_planning_feedback_repository.dart';
import 'package:questra/features/quest/quest_progress_service.dart';

void main() {
  Mission mission(String id, MissionStatus status, [int? progress]) {
    return Mission(
      id: id,
      questId: 'quest-1',
      questTitle: 'シンガポールへ行く',
      title: 'Mission $id',
      description: '一つの完了条件',
      guideType: GuideType.route,
      difficulty: MissionDifficulty.easy,
      status: status,
      progressPercent: progress,
    );
  }

  test('Quest progress uses completed required Mission outcomes', () {
    final snapshot = const QuestProgressService().calculate([
      mission('1', MissionStatus.completed),
      mission('2', MissionStatus.todo, 50),
      mission('3', MissionStatus.todo, 0),
    ]);

    expect(snapshot.completed, 1);
    expect(snapshot.total, 3);
    expect(snapshot.percent, 33);
  });

  test('completed Mission defaults to 100 percent', () {
    expect(mission('1', MissionStatus.completed).progressPercent, 100);
  });

  test('planning feedback stores no raw consultation text', () async {
    final repository = InMemoryQuestPlanningFeedbackRepository();
    await repository.save(
      const QuestPlanningFeedback(
        questId: 'quest-1',
        categoryKey: '旅行',
        sourceType: 'gemini_arc_quest_guide',
        generatedCount: 10,
        acceptedCount: 8,
        editedCount: 2,
        targetWindow: 'within_1_year',
      ),
    );

    expect(repository.feedback.single.acceptedCount, 8);
    expect(repository.feedback.single.categoryKey, '旅行');
  });

  test('target date becomes a reusable non-identifying window', () {
    final now = DateTime(2026, 7, 24);
    expect(questTargetWindow(DateTime(2026, 10, 1), now), 'within_90_days');
    expect(questTargetWindow(null, now), 'unspecified');
  });
}
