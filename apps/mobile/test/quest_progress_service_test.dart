import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_progress_service.dart';

void main() {
  const service = QuestProgressService();

  test('zero Missions produce zero progress', () {
    final snapshot = service.calculate(const []);

    expect(snapshot.value, 0);
    expect(snapshot.percent, 0);
    expect(snapshot.missionCountLabel, '0/0');
  });

  test('completed Missions determine progress and count label', () {
    final missions = [
      _mission('1', MissionStatus.completed),
      _mission('2', MissionStatus.completed),
      _mission('3', MissionStatus.todo),
      _mission('4', MissionStatus.todo),
    ];

    final snapshot = service.calculate(missions);

    expect(snapshot.value, 0.5);
    expect(snapshot.percent, 50);
    expect(snapshot.missionCountLabel, '2/4');
  });
}

Mission _mission(String id, MissionStatus status) {
  return Mission(
    id: id,
    questId: 'quest-1',
    questTitle: 'Quest',
    title: 'Mission $id',
    description: '',
    guideType: GuideType.route,
    difficulty: MissionDifficulty.easy,
    status: status,
  );
}
