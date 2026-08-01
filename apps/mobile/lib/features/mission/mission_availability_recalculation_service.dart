import 'dart:math' as math;

import 'mission_model.dart';

class MissionAvailabilityRecalculationService {
  const MissionAvailabilityRecalculationService();

  Mission recalculate(
    Mission mission, {
    required int previousWeeklyMinutes,
    required int nextWeeklyMinutes,
  }) {
    if (mission.status == MissionStatus.completed || nextWeeklyMinutes <= 0) {
      return mission;
    }
    final activeMinutes = mission.effortEstimate?.activeEffortMinutes;
    final currentDays = mission.estimatedDurationDays;
    int? nextDays;
    if (activeMinutes != null && activeMinutes > 0) {
      nextDays = math.max(1, (activeMinutes * 7 / nextWeeklyMinutes).ceil());
    } else if (currentDays != null && previousWeeklyMinutes > 0) {
      nextDays = math.max(
        1,
        (currentDays * previousWeeklyMinutes / nextWeeklyMinutes).ceil(),
      );
    }
    if (nextDays == null) return mission;
    return mission.copyWith(estimatedDurationDays: nextDays.clamp(1, 3650));
  }
}
