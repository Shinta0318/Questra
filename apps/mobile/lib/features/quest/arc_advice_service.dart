import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../arc/arc_emotion.dart';
import 'quest_guide_model.dart';
import 'quest_model.dart';

abstract interface class ArcAdviceService {
  Future<ArcAdvice> generate({required Quest quest, required QuestGuide guide});
}

class LocalArcAdviceService implements ArcAdviceService {
  const LocalArcAdviceService();

  @override
  Future<ArcAdvice> generate({
    required Quest quest,
    required QuestGuide guide,
  }) async {
    return ArcAdvice(
      questId: quest.id,
      guideType: guide.guideType,
      adviceText:
          'For ${quest.title}, choose one ${guide.guideType.label.toLowerCase()} step that can be recorded today.',
      emotion: guide.guideType == GuideType.training
          ? ArcEmotion.support
          : ArcEmotion.normal,
    );
  }
}

class SupabaseArcAdviceService implements ArcAdviceService {
  const SupabaseArcAdviceService({
    required this.client,
    this.fallback = const LocalArcAdviceService(),
  });

  final SupabaseClient client;
  final ArcAdviceService fallback;

  @override
  Future<ArcAdvice> generate({
    required Quest quest,
    required QuestGuide guide,
  }) async {
    try {
      final response = await client.functions.invoke(
        'generate-arc-advice',
        body: {
          'quest': {'id': quest.id, 'title': quest.title},
          'guide': {
            'id': guide.id,
            'guide_type': guide.guideType.name,
            'title': guide.title,
            'description': guide.description,
          },
        },
      );

      final data = Map<String, dynamic>.from(response.data as Map);
      return ArcAdvice(
        questId: quest.id,
        guideType: _guideTypeFromValue(data['guide_type'] as String?),
        adviceText:
            data['advice_text'] as String? ??
            'Take the smallest clear step first.',
        emotion: _emotionFromValue(data['emotion'] as String?),
        sourceType: data['source_type'] as String? ?? 'arc_advice',
      );
    } catch (_) {
      return fallback.generate(quest: quest, guide: guide);
    }
  }

  GuideType _guideTypeFromValue(String? value) {
    return GuideType.values.firstWhere(
      (guideType) => guideType.name == value,
      orElse: () => GuideType.route,
    );
  }

  ArcEmotion _emotionFromValue(String? value) {
    return ArcEmotion.values.firstWhere(
      (emotion) => emotion.name == value,
      orElse: () => ArcEmotion.normal,
    );
  }
}
