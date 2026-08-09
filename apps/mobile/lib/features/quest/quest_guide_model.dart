import 'package:uuid/uuid.dart';

import '../arc/arc_emotion.dart';

const _uuid = Uuid();

enum GuideType { route, knowledge, training, guild, resource, opportunity }

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
      GuideType.route => '航路ガイド',
      GuideType.knowledge => '知識ガイド',
      GuideType.training => '練習ガイド',
      GuideType.guild => 'Guildガイド',
      GuideType.resource => '資料ガイド',
      GuideType.opportunity => '機会ガイド',
    };
  }
}
