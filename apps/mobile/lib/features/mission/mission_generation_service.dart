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
      GuideType.route => 'Sketch one checkpoint',
      GuideType.knowledge => 'Learn one missing idea',
      GuideType.training => 'Practice one tiny rep',
      GuideType.guild => 'Ask one Guild question',
      GuideType.resource => 'Prepare one useful resource',
      GuideType.opportunity => 'Find one possible opening',
    };
  }

  String _descriptionForGuide(QuestGuide guide, ArcAdvice? advice) {
    final action = guide.suggestedActions.first;
    final arcLine = advice == null ? '' : ' Arc says: ${advice.adviceText}';
    return '$action. Keep it concrete and finishable in 5 to 30 minutes today.$arcLine';
  }
}
