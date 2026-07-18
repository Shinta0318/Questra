import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/mission/mission_repository.dart';
import 'package:questra/features/quest/quest_guide_model.dart';

void main() {
  test('Mission repository preserves planning fields and sort order', () async {
    final repository = InMemoryMissionRepository();
    final later = Mission(
      questId: 'quest-1',
      questTitle: 'Quest',
      title: 'Later',
      description: 'Second step',
      guideType: GuideType.training,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.todo,
      sortOrder: 1,
    );
    final today = Mission(
      questId: 'quest-1',
      questTitle: 'Quest',
      title: 'Today',
      description: 'First step',
      guideType: GuideType.route,
      difficulty: MissionDifficulty.normal,
      status: MissionStatus.todo,
      sortOrder: 0,
      isToday: true,
    );

    await repository.save(later);
    await repository.save(today);
    final loaded = await repository.findByQuest('quest-1');

    expect(loaded.map((mission) => mission.title), ['Today', 'Later']);
    expect(loaded.first.isToday, isTrue);
    expect(loaded.first.sortOrder, 0);
  });

  test('Mission copyWith edits content without losing planning fields', () {
    final mission = Mission(
      questId: 'quest-1',
      questTitle: 'Quest',
      title: 'Before',
      description: 'Before description',
      guideType: GuideType.route,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.todo,
      sortOrder: 3,
      isToday: true,
    );

    final updated = mission.copyWith(title: 'After', description: 'Updated');

    expect(updated.title, 'After');
    expect(updated.description, 'Updated');
    expect(updated.sortOrder, 3);
    expect(updated.isToday, isTrue);
  });
}
