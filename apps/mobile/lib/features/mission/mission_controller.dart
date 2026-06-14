import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../quest/quest_guide_model.dart';
import '../quest/quest_model.dart';
import 'mission_generation_service.dart';
import 'mission_model.dart';

final missionGenerationServiceProvider = Provider<MissionGenerationService>(
  (ref) => const MissionGenerationService(),
);

final missionControllerProvider =
    NotifierProvider<MissionController, List<Mission>>(MissionController.new);

class MissionController extends Notifier<List<Mission>> {
  @override
  List<Mission> build() => const [];

  Mission? get todaysMission {
    final openMissions = state
        .where((mission) => mission.status == MissionStatus.todo)
        .toList();
    if (openMissions.isEmpty) {
      return null;
    }
    openMissions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return openMissions.first;
  }

  Mission generateMission({
    required Quest quest,
    required QuestGuide guide,
    ArcAdvice? advice,
  }) {
    final mission = ref
        .read(missionGenerationServiceProvider)
        .generate(quest: quest, guide: guide, advice: advice);
    state = [mission, ...state];
    return mission;
  }

  void completeMission(String missionId) {
    state = [
      for (final mission in state)
        if (mission.id == missionId)
          mission.copyWith(status: MissionStatus.completed)
        else
          mission,
    ];
  }
}
