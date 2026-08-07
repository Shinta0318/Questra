import 'mission_model.dart';

enum MissionRegenerationIntent {
  moreSpecific,
  smaller,
  lowerBudget,
  beginnerFriendly,
  clarifyDoneCondition,
  reorder,
  fitDeadline,
  harder,
  selfManaged,
  removeUnneeded,
  alternative,
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
      MissionRegenerationIntent.fitDeadline => '希望期限に収まる現実的な行動量へ調整する',
      MissionRegenerationIntent.harder => '経験者向けに挑戦度と成果水準を上げる',
      MissionRegenerationIntent.selfManaged => '外部サービスに頼らず自分で進められる形にする',
      MissionRegenerationIntent.removeUnneeded => '不要なら削除候補として理由を明確にする',
      MissionRegenerationIntent.alternative => '同じ目的を満たす別の進め方へ置き換える',
    };
  }
}

extension MissionRegenerationIntentLabel on MissionRegenerationIntent {
  String get label => switch (this) {
    MissionRegenerationIntent.moreSpecific => 'もっと具体的に',
    MissionRegenerationIntent.smaller => 'もっと小さく',
    MissionRegenerationIntent.lowerBudget => '費用を抑える',
    MissionRegenerationIntent.beginnerFriendly => '初心者向け',
    MissionRegenerationIntent.clarifyDoneCondition => '完了条件を明確に',
    MissionRegenerationIntent.reorder => '順番を見直す',
    MissionRegenerationIntent.fitDeadline => '期限に合わせる',
    MissionRegenerationIntent.harder => '挑戦度を上げる',
    MissionRegenerationIntent.selfManaged => '自分で進める',
    MissionRegenerationIntent.removeUnneeded => '不要か見直す',
    MissionRegenerationIntent.alternative => '別の方法',
  };
}
