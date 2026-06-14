import 'arc_memory_model.dart';
import 'arc_memory_repository.dart';

class MemoryExtractionService {
  const MemoryExtractionService({required this.repository});

  final ArcMemoryRepository repository;

  Future<List<ArcMemory>> extractAndSave(MemoryExtractionEvent event) async {
    final candidate = extractCandidate(event);
    if (candidate == null) {
      return const [];
    }

    if (await repository.existsByDedupeKey(candidate.dedupeKey)) {
      return const [];
    }

    await repository.save(candidate);
    return [candidate];
  }

  ArcMemory? extractCandidate(MemoryExtractionEvent event) {
    final cleaned = _redactSensitiveText(event.text.trim());
    if (!_shouldRemember(cleaned, event)) {
      return null;
    }

    final memoryType = _classifyMemoryType(event, cleaned);
    final tone = _classifyTone(cleaned, event);
    final sensitivity = _classifySensitivity(event.text);
    final importance = _scoreImportance(cleaned, event, memoryType, tone);

    return ArcMemory(
      userId: event.userId,
      questId: event.questId,
      missionId: event.missionId,
      trailId: event.trailId,
      memoryType: memoryType,
      title: event.title ?? _titleFor(memoryType, event),
      content: cleaned,
      importanceScore: importance,
      emotionalTone: tone,
      sourceType: event.sourceType,
      sourceId: event.sourceId,
      metadata: {
        ...event.metadata,
        'extraction_version': 'rules_v1',
        'llm_ready': true,
      },
      sensitivityLevel: sensitivity,
      userVisible: sensitivity != SensitivityLevel.sensitive,
    );
  }

  bool _shouldRemember(String text, MemoryExtractionEvent event) {
    if (text.length < 12) {
      return false;
    }

    final lower = text.toLowerCase();
    final lowSignal = {'ok', 'yes', 'no', 'thanks', 'ありがとう', '了解', 'はい', 'うん'};
    if (lowSignal.contains(lower)) {
      return false;
    }

    if (event.questId != null ||
        event.missionId != null ||
        event.trailId != null) {
      return true;
    }

    return _containsPreference(text) ||
        _containsEmotion(text) ||
        _containsLifeEvent(text) ||
        event.sourceType == ArcMemorySourceType.arcChat ||
        event.sourceType == ArcMemorySourceType.guildPost;
  }

  ArcMemoryType _classifyMemoryType(MemoryExtractionEvent event, String text) {
    if (_containsLifeEvent(text)) {
      return ArcMemoryType.lifeEventMemory;
    }
    if (_containsPreference(text)) {
      return ArcMemoryType.preferenceMemory;
    }
    if (_containsEmotion(text)) {
      return ArcMemoryType.emotionalMemory;
    }

    return switch (event.sourceType) {
      ArcMemorySourceType.questCreated ||
      ArcMemorySourceType.questUpdated => ArcMemoryType.questMemory,
      ArcMemorySourceType.missionCreated ||
      ArcMemorySourceType.missionCompleted => ArcMemoryType.missionMemory,
      ArcMemorySourceType.trailPosted => ArcMemoryType.trailMemory,
      ArcMemorySourceType.arcChat => ArcMemoryType.arcRelationshipMemory,
      ArcMemorySourceType.guildPost => ArcMemoryType.trailMemory,
    };
  }

  EmotionalTone _classifyTone(String text, MemoryExtractionEvent event) {
    final lower = text.toLowerCase();
    if (_containsAny(lower, ['嬉しい', '楽しい', 'excited', '楽しみ'])) {
      return EmotionalTone.excited;
    }
    if (_containsAny(lower, ['完了', 'できた', '達成', 'celebrate', 'won'])) {
      return EmotionalTone.celebratory;
    }
    if (_containsAny(lower, ['不安', '心配', '怖い', 'worried', 'anxious'])) {
      return EmotionalTone.worried;
    }
    if (_containsAny(lower, ['孤独', 'ひとり', 'lonely'])) {
      return EmotionalTone.lonely;
    }
    if (event.sourceType == ArcMemorySourceType.missionCompleted) {
      return EmotionalTone.positive;
    }
    return EmotionalTone.neutral;
  }

  double _scoreImportance(
    String text,
    MemoryExtractionEvent event,
    ArcMemoryType type,
    EmotionalTone tone,
  ) {
    var score = 0.35;
    if (event.questId != null) {
      score += 0.18;
    }
    if (event.missionId != null || event.trailId != null) {
      score += 0.12;
    }
    if (type == ArcMemoryType.lifeEventMemory ||
        type == ArcMemoryType.preferenceMemory ||
        type == ArcMemoryType.arcRelationshipMemory) {
      score += 0.18;
    }
    if (tone != EmotionalTone.neutral) {
      score += 0.12;
    }
    if (text.length > 80) {
      score += 0.10;
    }
    return score.clamp(0.0, 1.0);
  }

  SensitivityLevel _classifySensitivity(String text) {
    final lower = text.toLowerCase();
    if (_containsAny(lower, [
      '病気',
      '診断',
      '住所',
      '電話',
      'パスワード',
      'password',
      'credit card',
      'クレジットカード',
    ])) {
      return SensitivityLevel.sensitive;
    }
    if (RegExp(r'[\w\.\-]+@[\w\.\-]+\.\w+').hasMatch(text) ||
        RegExp(r'\d{2,4}[-\s]?\d{2,4}[-\s]?\d{3,4}').hasMatch(text)) {
      return SensitivityLevel.personal;
    }
    return SensitivityLevel.standard;
  }

  String _redactSensitiveText(String text) {
    return text
        .replaceAll(RegExp(r'[\w\.\-]+@[\w\.\-]+\.\w+'), '[redacted-email]')
        .replaceAll(
          RegExp(r'\d{2,4}[-\s]?\d{2,4}[-\s]?\d{3,4}'),
          '[redacted-phone]',
        );
  }

  String _titleFor(ArcMemoryType type, MemoryExtractionEvent event) {
    return switch (type) {
      ArcMemoryType.questMemory => 'Quest memory',
      ArcMemoryType.missionMemory => 'Mission memory',
      ArcMemoryType.trailMemory => 'Trail memory',
      ArcMemoryType.preferenceMemory => 'Preference memory',
      ArcMemoryType.emotionalMemory => 'Emotional memory',
      ArcMemoryType.lifeEventMemory => 'Life event memory',
      ArcMemoryType.arcRelationshipMemory => 'Arc relationship memory',
    };
  }

  bool _containsPreference(String text) {
    return _containsAny(text.toLowerCase(), [
      '好き',
      '苦手',
      '大切',
      'prefer',
      'favorite',
      'value',
      'values',
      'important to me',
    ]);
  }

  bool _containsEmotion(String text) {
    return _containsAny(text.toLowerCase(), [
      '嬉しい',
      '楽しい',
      '不安',
      '心配',
      '怖い',
      '孤独',
      'excited',
      'worried',
      'anxious',
      'lonely',
    ]);
  }

  bool _containsLifeEvent(String text) {
    return _containsAny(text.toLowerCase(), [
      '引っ越し',
      '転職',
      '入学',
      '卒業',
      '結婚',
      '家族',
      'moved',
      'new job',
      'graduated',
      'family',
    ]);
  }

  bool _containsAny(String text, List<String> needles) {
    return needles.any(text.contains);
  }
}
