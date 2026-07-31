import '../mission/mission_model.dart';

enum GentleRecoveryAction { pause, shrink, reviewDeadline, fiveMinuteStep }

class GentleRecoverySuggestion {
  const GentleRecoverySuggestion({
    required this.question,
    required this.actions,
  });

  final String question;
  final List<GentleRecoveryAction> actions;
}

abstract final class GentleRecoveryService {
  static GentleRecoverySuggestion suggest({
    required Mission mission,
    required int inactiveDays,
  }) {
    if (inactiveDays >= 14) {
      return const GentleRecoverySuggestion(
        question: '今の航路を少し軽くして、また始められそう？',
        actions: [
          GentleRecoveryAction.pause,
          GentleRecoveryAction.fiveMinuteStep,
          GentleRecoveryAction.reviewDeadline,
        ],
      );
    }
    return GentleRecoverySuggestion(
      question: '「${mission.title}」を5分だけ進めるなら、何からなら始められそう？',
      actions: const [
        GentleRecoveryAction.fiveMinuteStep,
        GentleRecoveryAction.shrink,
      ],
    );
  }
}
