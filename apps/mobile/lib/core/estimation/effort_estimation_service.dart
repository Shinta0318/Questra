import 'effort_estimate.dart';

abstract final class EffortEstimationService {
  static EffortEstimate forQuest({
    required String title,
    required String category,
    int missionCount = 8,
  }) {
    final source = '$category $title';
    final longTerm = RegExp(r'(起業|転職|資格|マラソン|登山|語学|海外|旅行)').hasMatch(source);
    final activeMinutes = (longTerm ? 720 : 360) + missionCount * 45;
    final calendarDays = longTerm ? 90 : 30;
    return EffortEstimate(
      difficultyBand: longTerm ? '挑戦的' : '標準',
      activeEffortMinutes: activeMinutes,
      calendarDays: calendarDays,
      confidence: 0.55,
      rationale: '現在のQuestのテーマとMission数から算出した初期目安です。',
    );
  }

  static EffortEstimate forMission({
    required String title,
    required String description,
  }) {
    final complex =
        RegExp(r'(比較|予約|申請|練習|実行|作成|準備)').hasMatch('$title $description');
    return EffortEstimate(
      difficultyBand: complex ? '標準' : '軽め',
      activeEffortMinutes: complex ? 120 : 45,
      calendarDays: complex ? 7 : 2,
      confidence: 0.5,
      rationale: 'Missionの内容から算出した初期目安です。',
    );
  }
}
