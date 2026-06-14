import '../quest/quest_guide_model.dart';
import '../quest/quest_model.dart';
import 'mission_model.dart';

class MissionGenerationService {
  const MissionGenerationService();

  Mission generate({
    required Quest quest,
    required QuestGuide guide,
    ArcAdvice? advice,
  }) {
    return Mission(
      questId: quest.id,
      questTitle: quest.title,
      title: _titleForGuide(guide.guideType),
      description: _descriptionForGuide(guide, advice),
      guideType: guide.guideType,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.todo,
    );
  }

  String _titleForGuide(GuideType guideType) {
    return switch (guideType) {
      GuideType.route => '航路の目印を1つ決める',
      GuideType.knowledge => '足りない知識を1つ調べる',
      GuideType.training => '小さな練習を1回試す',
      GuideType.guild => 'Guildで質問を1つ考える',
      GuideType.resource => '必要な準備を1つ整える',
      GuideType.opportunity => '次の機会を1つ探す',
    };
  }

  String _descriptionForGuide(QuestGuide guide, ArcAdvice? advice) {
    final action = guide.suggestedActions.first;
    final arcLine = advice == null ? '' : ' Arcより: ${advice.adviceText}';
    return '$action。5〜30分で終わる小さなMissionにしよう。小さなMissionも、ちゃんと前進だよ。$arcLine';
  }
}
