import 'mission_model.dart';

enum MissionRegenerationIntent {
  moreSpecific,
  smaller,
  lowerBudget,
  beginnerFriendly,
  clarifyDoneCondition,
  reorder,
}

class MissionRegenerationRequest {
  const MissionRegenerationRequest({
    required this.mission,
    required this.intent,
  });

  final Mission mission;
  final MissionRegenerationIntent intent;

  bool get canRegenerate => mission.status != MissionStatus.completed;
}

abstract final class MissionRegenerationService {
  static String promptHint(MissionRegenerationRequest request) {
    return switch (request.intent) {
      MissionRegenerationIntent.moreSpecific => '対象、行動、記録する成果物を具体化する',
      MissionRegenerationIntent.smaller => '15分から始められる小さな行動へ分割する',
      MissionRegenerationIntent.lowerBudget => '費用を抑えた代替手段を優先する',
      MissionRegenerationIntent.beginnerFriendly => '前提知識を減らし、最初の一歩から設計する',
      MissionRegenerationIntent.clarifyDoneCondition => '第三者にも判定できる完了条件を追加する',
      MissionRegenerationIntent.reorder => '依存関係を保ちつつ実行順を見直す',
    };
  }
}
