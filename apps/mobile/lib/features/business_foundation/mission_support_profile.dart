enum MissionSupportType {
  none,
  officialInformation,
  comparison,
  learning,
  professionalAdvice,
  reservation,
  product,
  rental,
  localExperience,
  community,
  financialPlanning,
  transportation,
  accommodation,
  other,
}

enum MissionCommercialIntent {
  none,
  awareness,
  consideration,
  preparation,
  readyForAction,
}

enum MissionActionWindow {
  now,
  within7Days,
  within30Days,
  within90Days,
  later,
  unknown,
}

extension MissionSupportStorage on Enum {
  String get storageKey => switch (this) {
    MissionCommercialIntent.readyForAction => 'ready_for_action',
    MissionActionWindow.within7Days => 'within_7_days',
    MissionActionWindow.within30Days => 'within_30_days',
    MissionActionWindow.within90Days => 'within_90_days',
    _ => name,
  };
}

enum MissionSupportSensitivity { normal, restricted, prohibited }

class MissionSupportProfile {
  const MissionSupportProfile({
    required this.supportTypes,
    required this.externalServiceNeeded,
    required this.providerCategories,
    required this.commercialIntent,
    required this.actionWindow,
    required this.sponsorable,
    required this.sensitivity,
    required this.userConsentRequired,
    required this.businessRecommendationsEnabled,
    required this.confidence,
    required this.source,
  });
  final Set<MissionSupportType> supportTypes;
  final bool externalServiceNeeded;
  final List<String> providerCategories;
  final MissionCommercialIntent commercialIntent;
  final MissionActionWindow actionWindow;
  final bool sponsorable;
  final MissionSupportSensitivity sensitivity;
  final bool userConsentRequired;
  final bool businessRecommendationsEnabled;
  final double confidence;
  final String source;
  MissionSupportProfile copyWith({
    Set<MissionSupportType>? supportTypes,
    bool? externalServiceNeeded,
    bool? businessRecommendationsEnabled,
    String? source,
  }) => MissionSupportProfile(
    supportTypes: supportTypes ?? this.supportTypes,
    externalServiceNeeded: externalServiceNeeded ?? this.externalServiceNeeded,
    providerCategories: providerCategories,
    commercialIntent: commercialIntent,
    actionWindow: actionWindow,
    sponsorable: sponsorable,
    sensitivity: sensitivity,
    userConsentRequired: userConsentRequired,
    businessRecommendationsEnabled:
        businessRecommendationsEnabled ?? this.businessRecommendationsEnabled,
    confidence: confidence,
    source: source ?? this.source,
  );
}

class MissionSupportClassifier {
  const MissionSupportClassifier();
  MissionSupportProfile classify(String text) {
    final source = text.toLowerCase();
    final sensitive = RegExp(r'医療|病気|借金|金融|家族問題|性的|宗教|政治').hasMatch(source);
    final travel = RegExp(r'航空券|ホテル|宿泊|移動|旅行|予約').hasMatch(source);
    final learning = RegExp(r'学習|勉強|資格|講座').hasMatch(source);
    final purchase = RegExp(r'購入|買う|比較|レンタル').hasMatch(source);
    final types = <MissionSupportType>{};
    if (travel) {
      types.addAll({
        MissionSupportType.transportation,
        MissionSupportType.reservation,
      });
    }
    if (learning) {
      types.add(MissionSupportType.learning);
    }
    if (purchase) {
      types.add(MissionSupportType.comparison);
    }
    if (types.isEmpty) {
      types.add(MissionSupportType.none);
    }
    final external = !types.contains(MissionSupportType.none);
    return MissionSupportProfile(
      supportTypes: types,
      externalServiceNeeded: external,
      providerCategories: travel
          ? const ['travel_service']
          : learning
          ? const ['learning_provider']
          : const [],
      commercialIntent: external
          ? MissionCommercialIntent.consideration
          : MissionCommercialIntent.none,
      actionWindow: MissionActionWindow.unknown,
      sponsorable: false,
      sensitivity: sensitive
          ? MissionSupportSensitivity.prohibited
          : MissionSupportSensitivity.normal,
      userConsentRequired: external,
      businessRecommendationsEnabled: false,
      confidence: 0.72,
      source: 'system',
    );
  }
}
