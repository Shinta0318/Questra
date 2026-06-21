enum MissionSignalType {
  overdueQuest,
  dueSoonQuest,
  staleMission,
  suggestedSmallStep,
}

enum MissionSignalSeverity { calm, focus, urgent }

class MissionSignal {
  const MissionSignal({
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    this.questId,
    this.missionId,
  });

  final MissionSignalType type;
  final MissionSignalSeverity severity;
  final String title;
  final String message;
  final String? questId;
  final String? missionId;
}

extension MissionSignalSeverityLabel on MissionSignalSeverity {
  String get label {
    return switch (this) {
      MissionSignalSeverity.calm => 'Signal',
      MissionSignalSeverity.focus => 'Focus Signal',
      MissionSignalSeverity.urgent => 'Urgent Signal',
    };
  }
}
