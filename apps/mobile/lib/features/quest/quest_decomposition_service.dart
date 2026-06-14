import '../arc/arc_emotion.dart';
import 'quest_guide_model.dart';
import 'quest_model.dart';

class QuestDecompositionBundle {
  const QuestDecompositionBundle({
    required this.guides,
    required this.advice,
    required this.starMap,
  });

  final List<QuestGuide> guides;
  final List<ArcAdvice> advice;
  final List<StarMapItem> starMap;
}

class QuestDecompositionService {
  const QuestDecompositionService();

  QuestDecompositionBundle generateForQuest(Quest quest) {
    final guides = GuideType.values
        .map(
          (guideType) => QuestGuide(
            questId: quest.id,
            guideType: guideType,
            title: _guideTitle(quest.title, guideType),
            description: _guideDescription(quest, guideType),
            suggestedActions: _suggestedActions(guideType),
          ),
        )
        .toList();

    final advice = guides
        .map(
          (guide) => ArcAdvice(
            questId: quest.id,
            guideType: guide.guideType,
            adviceText: _adviceText(quest.title, guide.guideType),
            emotion: _emotionForGuide(guide.guideType),
          ),
        )
        .toList();

    final starMap = guides
        .map(
          (guide) => StarMapItem(
            questId: quest.id,
            guideType: guide.guideType,
            title: '${guide.guideType.label} reference',
            description:
                'A neutral external resource to support ${quest.title}.',
            url: 'https://example.com/${guide.guideType.name}',
            contentType: _contentTypeForGuide(guide.guideType),
          ),
        )
        .toList();

    return QuestDecompositionBundle(
      guides: guides,
      advice: advice,
      starMap: starMap,
    );
  }

  String _guideTitle(String questTitle, GuideType guideType) {
    return '${guideType.label}: $questTitle';
  }

  String _guideDescription(Quest quest, GuideType guideType) {
    return switch (guideType) {
      GuideType.route => 'Break ${quest.title} into a visible path.',
      GuideType.knowledge => 'Identify what you need to learn first.',
      GuideType.training => 'Practice the smallest repeatable skill.',
      GuideType.guild =>
        'Find Guild allies or spaces that can support progress.',
      GuideType.resource => 'Collect tools, references, and materials.',
      GuideType.opportunity =>
        'Notice non-commercial openings that help you move forward.',
    };
  }

  List<String> _suggestedActions(GuideType guideType) {
    return switch (guideType) {
      GuideType.route => [
        'Write the finish line',
        'Choose three milestones',
        'Pick the next checkpoint',
      ],
      GuideType.knowledge => [
        'List unknowns',
        'Read one beginner reference',
        'Write one question for Arc',
      ],
      GuideType.training => [
        'Practice for 10 minutes',
        'Repeat one core move',
        'Record what felt hard',
      ],
      GuideType.guild => [
        'Name one helpful Guild ally',
        'Find one relevant Guild space',
        'Ask one small question',
      ],
      GuideType.resource => [
        'Save one useful tool',
        'Prepare your workspace',
        'Remove one blocker',
      ],
      GuideType.opportunity => [
        'Look for one event or opening',
        'Bookmark one learning chance',
        'Choose one next door to knock on',
      ],
    };
  }

  String _adviceText(String questTitle, GuideType guideType) {
    return switch (guideType) {
      GuideType.route =>
        'For "$questTitle", make the path visible before you sprint.',
      GuideType.knowledge =>
        'Start with one missing idea. Understanding grows in layers.',
      GuideType.training =>
        'Choose a tiny rep today. Five focused minutes still count.',
      GuideType.guild =>
        'A Guild works best when you ask for one clear signal, not a crowd.',
      GuideType.resource =>
        'Gather only what supports the next action. Keep the pack light.',
      GuideType.opportunity =>
        'Look for openings, not offers. This is about momentum, not selling.',
    };
  }

  ArcEmotion _emotionForGuide(GuideType guideType) {
    return switch (guideType) {
      GuideType.route => ArcEmotion.serious,
      GuideType.knowledge => ArcEmotion.normal,
      GuideType.training => ArcEmotion.support,
      GuideType.guild => ArcEmotion.excited,
      GuideType.resource => ArcEmotion.normal,
      GuideType.opportunity => ArcEmotion.celebrate,
    };
  }

  String _contentTypeForGuide(GuideType guideType) {
    return switch (guideType) {
      GuideType.route => 'framework',
      GuideType.knowledge => 'article',
      GuideType.training => 'exercise',
      GuideType.guild => 'guild',
      GuideType.resource => 'tool',
      GuideType.opportunity => 'event',
    };
  }
}
