enum RouteReplanningTrigger {
  missionCompleted,
  missionPostponed,
  missionDeadlineMissed,
  inactive,
  questChanged,
  approvedContextChanged,
  manual,
  weeklyReview,
}

class RouteTriggerDecision {
  const RouteTriggerDecision({
    required this.shouldEvaluate,
    required this.dedupeKey,
    required this.reason,
  });

  final bool shouldEvaluate;
  final String dedupeKey;
  final String reason;
}

class RouteReplanningTriggerService {
  const RouteReplanningTriggerService({
    this.cooldown = const Duration(hours: 24),
  });

  final Duration cooldown;

  RouteTriggerDecision decide({
    required String questId,
    required RouteReplanningTrigger trigger,
    DateTime? lastEvaluatedAt,
    String? eventId,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final isManual = trigger == RouteReplanningTrigger.manual;
    final isUrgent = trigger == RouteReplanningTrigger.missionDeadlineMissed;
    final coolingDown = lastEvaluatedAt != null &&
        current.difference(lastEvaluatedAt) < cooldown;
    final shouldEvaluate = isManual || isUrgent || !coolingDown;
    final period = '${current.year}-${current.month}-${current.day}';
    return RouteTriggerDecision(
      shouldEvaluate: shouldEvaluate,
      dedupeKey: '$questId:${trigger.name}:${eventId ?? period}',
      reason: shouldEvaluate
          ? (isManual ? 'ユーザーが航路の見直しを依頼しました。' : '進捗イベントを検知しました。')
          : '直近で評価済みのため、AI呼び出しを省略しました。',
    );
  }
}
