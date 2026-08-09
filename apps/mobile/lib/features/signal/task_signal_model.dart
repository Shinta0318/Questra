import '../auth/auth_state.dart';

enum TaskSignalType { overdue, dueToday, dueSoon, stalled, ready }

enum TaskSignalSeverity { calm, focus, urgent }

class TaskSignal {
  const TaskSignal({
    required this.type,
    required this.severity,
    required this.taskId,
    required this.questId,
    required this.missionId,
    required this.title,
    required this.message,
  });

  final TaskSignalType type;
  final TaskSignalSeverity severity;
  final String taskId;
  final String questId;
  final String missionId;
  final String title;
  final String message;
}

class TaskSignalPreferences {
  const TaskSignalPreferences({
    this.notificationsEnabled = false,
    this.frequency = SignalFrequency.balanced,
    this.quietStartHour = 22,
    this.quietEndHour = 8,
  });

  final bool notificationsEnabled;
  final SignalFrequency frequency;
  final int quietStartHour;
  final int quietEndHour;

  bool isQuietHour(DateTime now) {
    if (quietStartHour == quietEndHour) return false;
    if (quietStartHour < quietEndHour) {
      return now.hour >= quietStartHour && now.hour < quietEndHour;
    }
    return now.hour >= quietStartHour || now.hour < quietEndHour;
  }
}

enum TaskSignalDeliveryDecision {
  deliver,
  suppressedWithoutConsent,
  suppressedDuringQuietHours,
}

class TaskSignalDeliveryPolicy {
  const TaskSignalDeliveryPolicy();

  TaskSignalDeliveryDecision evaluate({
    required TaskSignalPreferences preferences,
    required DateTime now,
  }) {
    if (!preferences.notificationsEnabled) {
      return TaskSignalDeliveryDecision.suppressedWithoutConsent;
    }
    if (preferences.isQuietHour(now)) {
      return TaskSignalDeliveryDecision.suppressedDuringQuietHours;
    }
    return TaskSignalDeliveryDecision.deliver;
  }
}

abstract interface class TaskSignalNotificationGateway {
  Future<void> schedule(TaskSignal signal);
}

class TaskSignalNotificationCoordinator {
  const TaskSignalNotificationCoordinator({
    this.policy = const TaskSignalDeliveryPolicy(),
  });

  final TaskSignalDeliveryPolicy policy;

  Future<TaskSignalDeliveryDecision> deliver({
    required TaskSignal signal,
    required TaskSignalPreferences preferences,
    required DateTime now,
    required TaskSignalNotificationGateway gateway,
  }) async {
    final decision = policy.evaluate(preferences: preferences, now: now);
    if (decision == TaskSignalDeliveryDecision.deliver) {
      await gateway.schedule(signal);
    }
    return decision;
  }
}
