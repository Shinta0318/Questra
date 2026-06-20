import 'tag_model.dart';

class TaggingInput {
  const TaggingInput({
    required this.ownerId,
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.body,
    this.context = const {},
  });

  final String ownerId;
  final TagEntityType entityType;
  final String entityId;
  final String title;
  final String body;
  final Map<String, Object?> context;
}

class GeneratedTag {
  const GeneratedTag({required this.name, required this.confidence});

  final String name;
  final double confidence;
}

abstract interface class AiTagService {
  Future<List<GeneratedTag>> generateTags(TaggingInput input);
}

class LocalAiTagService implements AiTagService {
  const LocalAiTagService();

  static const _keywordTags = <String, List<String>>{
    '富士山': ['Travel', 'Outdoor', 'Mountain', 'Fitness', 'Japan'],
    '登る': ['Outdoor', 'Mountain', 'Fitness'],
    '山': ['Outdoor', 'Mountain'],
    '英語': ['Language', 'Learning', 'Communication'],
    '話': ['Communication', 'Language'],
    '起業': ['Startup', 'Business', 'Product'],
    'ローンチ': ['Startup', 'Launch', 'Product'],
    '運動': ['Fitness', 'Health'],
    '学習': ['Learning', 'Skill'],
    '読書': ['Learning', 'Books'],
    '旅': ['Travel', 'Adventure'],
    'guild': ['Guild', 'Community'],
    'community': ['Community', 'Guild'],
    'trail': ['Trail', 'Reflection'],
    'reflection': ['Reflection', 'Learning'],
    'mission': ['Mission', 'Action'],
    'quest': ['Quest', 'Adventure'],
    'startup': ['Startup', 'Business'],
    'launch': ['Launch', 'Product'],
    'fitness': ['Fitness', 'Health'],
    'mountain': ['Mountain', 'Outdoor'],
    'travel': ['Travel', 'Adventure'],
    'english': ['Language', 'Learning'],
  };

  @override
  Future<List<GeneratedTag>> generateTags(TaggingInput input) async {
    final text =
        '${input.title}\n${input.body}\n${input.context.values.join(' ')}';
    final lower = text.toLowerCase();
    final tags = <String>{_entityTypeTag(input.entityType)};

    for (final entry in _keywordTags.entries) {
      if (lower.contains(entry.key.toLowerCase())) {
        tags.addAll(entry.value);
      }
    }

    final category = input.context['category'];
    if (category is String && category.trim().isNotEmpty) {
      tags.add(_titleCase(category.trim()));
    }

    final guideType = input.context['guide_type'];
    if (guideType is String && guideType.trim().isNotEmpty) {
      tags.add(_titleCase(guideType.trim()));
    }

    if (tags.length < 3) {
      tags.addAll(const ['Adventure', 'Growth', 'Personal']);
    }

    return tags
        .where((tag) => tag.trim().isNotEmpty)
        .take(8)
        .map((tag) => GeneratedTag(name: tag, confidence: _confidenceFor(tag)))
        .toList(growable: false);
  }

  String _entityTypeTag(TagEntityType entityType) {
    return switch (entityType) {
      TagEntityType.quest => 'Quest',
      TagEntityType.mission => 'Mission',
      TagEntityType.trail => 'Trail',
      TagEntityType.arcMemory => 'Memory',
    };
  }

  String _titleCase(String value) {
    final words = value
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    return words
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  double _confidenceFor(String tag) {
    if (tag == 'Quest' ||
        tag == 'Mission' ||
        tag == 'Trail' ||
        tag == 'Memory') {
      return 0.62;
    }
    return 0.78;
  }
}
