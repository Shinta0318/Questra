import 'quest_intent_model.dart';

abstract final class QuestIntentService {
  static final _literalImpossible = <RegExp, String>{
    RegExp(r'(過去|昔).{0,8}(戻|行く|変え)'): '過去の経験を受け止め、これからの選択を変える',
    RegExp(r'(不老不死|永遠に死なない)'): '健やかに長く暮らすための習慣をつくる',
    RegExp(r'(瞬間移動|テレポート)'): '移動の負担を減らし、行きたい場所へ効率よく行く',
  };

  static QuestIntentDraft frame({
    required String outcome,
    String motivation = '',
    String successCondition = '',
  }) {
    final normalized = outcome.trim();
    for (final entry in _literalImpossible.entries) {
      if (entry.key.hasMatch(normalized)) {
        return QuestIntentDraft(
          outcome: normalized,
          motivation: motivation.trim(),
          successCondition: successCondition.trim(),
          realityFrame: QuestRealityFrame.symbolic,
          reframedOutcome: entry.value,
        );
      }
    }
    final ambitious = RegExp(
      r'(世界一|日本一|オリンピック|宇宙飛行士|ノーベル賞|100億|上場)',
    ).hasMatch(normalized);
    return QuestIntentDraft(
      outcome: normalized,
      motivation: motivation.trim(),
      successCondition: successCondition.trim(),
      realityFrame: ambitious
          ? QuestRealityFrame.ambitious
          : QuestRealityFrame.uncertain,
    );
  }
}
