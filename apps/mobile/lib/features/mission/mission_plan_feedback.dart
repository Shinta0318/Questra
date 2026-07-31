enum MissionPlanFeedbackReason {
  useful,
  notForMe,
  tooAbstract,
  tooHard,
  tooEasy,
  wrongOrder,
  alreadyDone,
  unnecessary,
  outdated,
  preferAnotherWay,
}

class MissionPlanFeedback {
  const MissionPlanFeedback({
    required this.questId,
    required this.missionId,
    required this.reason,
    required this.generationVersion,
  });

  final String questId;
  final String missionId;
  final MissionPlanFeedbackReason reason;
  final String generationVersion;

  Map<String, Object?> toInsert(String ownerId) => {
    'owner_id': ownerId,
    'quest_id': questId,
    'mission_id': missionId,
    'reason': reason.name,
    'generation_version': generationVersion,
  };
}
