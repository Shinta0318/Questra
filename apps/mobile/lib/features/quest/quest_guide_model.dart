import 'package:uuid/uuid.dart';

import '../arc/arc_emotion.dart';

const _uuid = Uuid();

enum GuideType { route, knowledge, training, community, resource, opportunity }

class QuestGuide {
  QuestGuide({
    String? id,
    required this.questId,
    required this.guideType,
    required this.title,
    required this.description,
    required this.suggestedActions,
  }) : id = id ?? _uuid.v4();

  final String id;
  final String questId;
  final GuideType guideType;
  final String title;
  final String description;
  final List<String> suggestedActions;
}

class ArcAdvice {
  ArcAdvice({
    String? id,
    required this.questId,
    required this.guideType,
    required this.adviceText,
    required this.emotion,
    this.sourceType = 'arc_advice',
  }) : id = id ?? _uuid.v4();

  final String id;
  final String questId;
  final GuideType guideType;
  final String adviceText;
  final ArcEmotion emotion;
  final String sourceType;
}

class StarMapItem {
  StarMapItem({
    String? id,
    required this.questId,
    required this.guideType,
    required this.title,
    required this.description,
    required this.url,
    required this.contentType,
    this.sourceType = 'star_map',
  }) : id = id ?? _uuid.v4();

  final String id;
  final String questId;
  final GuideType guideType;
  final String title;
  final String description;
  final String url;
  final String contentType;
  final String sourceType;
}

extension GuideTypeLabel on GuideType {
  String get label {
    return switch (this) {
      GuideType.route => 'Route Guide',
      GuideType.knowledge => 'Knowledge Guide',
      GuideType.training => 'Training Guide',
      GuideType.community => 'Community Guide',
      GuideType.resource => 'Resource Guide',
      GuideType.opportunity => 'Opportunity Guide',
    };
  }
}
