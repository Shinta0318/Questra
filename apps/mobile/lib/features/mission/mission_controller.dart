import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../quest/quest_guide_model.dart';
import '../quest/quest_model.dart';
import 'mission_model.dart';

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
    final mission = Mission(
      questId: quest.id,
      questTitle: quest.title,
      title: _titleForGuide(guide.guideType),
      description: _descriptionForGuide(guide, advice),
      guideType: guide.guideType,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.todo,
    );
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

  String _titleForGuide(GuideType guideType) {
    return switch (guideType) {
      GuideType.route => 'Sketch one checkpoint',
      GuideType.knowledge => 'Learn one missing idea',
      GuideType.training => 'Practice one tiny rep',
      GuideType.community => 'Ask one small question',
      GuideType.resource => 'Prepare one useful resource',
      GuideType.opportunity => 'Find one possible opening',
    };
  }

  String _descriptionForGuide(QuestGuide guide, ArcAdvice? advice) {
    final action = guide.suggestedActions.first;
    final arcLine = advice == null ? '' : ' Arc says: ${advice.adviceText}';
    return '$action. Keep it concrete and finishable in 5 to 30 minutes today.$arcLine';
  }
}
