import '../quest/gentle_recovery_service.dart';

enum MissionSignalType {
  overdueQuest,
  dueSoonQuest,
  staleMission,
  suggestedSmallStep,
}

enum MissionSignalSeverity { calm, focus, urgent }

enum MissionSignalPressure { low, medium }

class MissionSignal {
  const MissionSignal({
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    this.questId,
    this.missionId,
    this.recoveryActions = const [],
    this.pressure = MissionSignalPressure.low,
  });

  final MissionSignalType type;
  final MissionSignalSeverity severity;
  final String title;
  final String message;
  final String? questId;
  final String? missionId;
  final List<GentleRecoveryAction> recoveryActions;
  final MissionSignalPressure pressure;

  bool get offersRest => recoveryActions.contains(GentleRecoveryAction.pause);
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
