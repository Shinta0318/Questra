enum QuestDnaAttributeSource { user, arc, behavior, system, safetyEngine }

enum BusinessSensitivity { normal, restricted, prohibitedForBusiness }

class QuestDnaValue<T> {
  const QuestDnaValue({
    required this.value,
    required this.confidence,
    required this.source,
  });
  final T value;
  final double confidence;
  final QuestDnaAttributeSource source;
  Map<String, Object?> toJson() => {
    'value': value,
    'confidence': confidence.clamp(0, 1),
    'source': source.name,
  };
}

class BusinessReadyQuestDna {
  const BusinessReadyQuestDna({
    required this.version,
    required this.attributes,
    required this.sensitivity,
  });
  final int version;
  final Map<String, QuestDnaValue<Object?>> attributes;
  final BusinessSensitivity sensitivity;
  Map<String, Object?> toJson() => {
    'version': version,
    'attributes': attributes.map((key, value) => MapEntry(key, value.toJson())),
    'sensitivity_level': sensitivity.name,
  };
}

class QuestSensitivityClassifier {
  const QuestSensitivityClassifier();
  BusinessSensitivity classify(String text) {
    final normalized = text.toLowerCase();
    if (RegExp(
      r'性|性的|宗教|政治|病気|病歴|借金|家庭問題|家族問題|自傷|自殺|依存症',
    ).hasMatch(normalized)) {
      return BusinessSensitivity.prohibitedForBusiness;
    }
    if (RegExp(r'健康|医療|お金|金融|妊娠|介護').hasMatch(normalized)) {
      return BusinessSensitivity.restricted;
    }
    return BusinessSensitivity.normal;
  }
}

class BusinessQuestSignalPolicy {
  const BusinessQuestSignalPolicy();
  static const allowedAttributes = {
    'category',
    'theme',
    'stage',
    'target_period_band',
    'budget_band',
    'location_scope',
    'experience_level',
    'support_needs',
    'commercial_relevance',
  };
  bool canGenerate({
    required bool consentGranted,
    required BusinessSensitivity sensitivity,
  }) => consentGranted && sensitivity == BusinessSensitivity.normal;
  Map<String, Object?> derive(Map<String, Object?> source) => {
    for (final entry in source.entries)
      if (allowedAttributes.contains(entry.key)) entry.key: entry.value,
  };
}
