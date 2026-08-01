import '../../core/estimation/effort_estimate.dart';

enum QuestFeasibility { comfortable, achievable, tight, unlikely }

class QuestFeasibilityResult {
  const QuestFeasibilityResult({
    required this.status,
    required this.requestedMonth,
    required this.likelyMonth,
    required this.message,
  });

  final QuestFeasibility status;
  final DateTime requestedMonth;
  final DateTime likelyMonth;
  final String message;
}

abstract final class QuestFeasibilityService {
  static QuestFeasibilityResult assess({
    required DateTime now,
    required DateTime requestedMonth,
    required EffortEstimate estimate,
  }) {
    final requested = DateTime(requestedMonth.year, requestedMonth.month);
    final likelyDate = now.add(Duration(days: estimate.calendarDays));
    final likely = DateTime(likelyDate.year, likelyDate.month);
    final monthGap =
        (requested.year - likely.year) * 12 + requested.month - likely.month;
    final status = monthGap >= 2
        ? QuestFeasibility.comfortable
        : monthGap >= 0
        ? QuestFeasibility.achievable
        : monthGap == -1
        ? QuestFeasibility.tight
        : QuestFeasibility.unlikely;
    final message = switch (status) {
      QuestFeasibility.comfortable => '余白を持って進められそうです。',
      QuestFeasibility.achievable => '現在の航路なら、希望月を目指せる見込みです。',
      QuestFeasibility.tight => '少しタイトです。Missionの範囲か進む頻度を調整しましょう。',
      QuestFeasibility.unlikely =>
        '${likely.year}/${likely.month.toString().padLeft(2, '0')}頃への変更、範囲縮小、進む頻度の見直しを提案します。',
    };
    return QuestFeasibilityResult(
      status: status,
      requestedMonth: requested,
      likelyMonth: likely,
      message: message,
    );
  }
}
