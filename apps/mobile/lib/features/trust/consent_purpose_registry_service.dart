enum ConsentPurpose {
  arcPersonalization,
  productImprovement,
  anonymousAnalytics,
  businessRecommendations,
  businessSegmentAnalysis,
  personalDataSharing,
}

extension ConsentPurposeStorage on ConsentPurpose {
  String get storageKey => switch (this) {
    ConsentPurpose.arcPersonalization => 'arc_personalization',
    ConsentPurpose.productImprovement => 'product_improvement',
    ConsentPurpose.anonymousAnalytics => 'anonymous_analytics',
    ConsentPurpose.businessRecommendations => 'business_recommendations',
    ConsentPurpose.businessSegmentAnalysis => 'business_segment_analysis',
    ConsentPurpose.personalDataSharing => 'personal_data_sharing',
  };
}

class ConsentPurposeDefinition {
  const ConsentPurposeDefinition({
    required this.purpose,
    required this.title,
    required this.summary,
    required this.dataScope,
    required this.defaultStateLabel,
    required this.canWithdraw,
    this.requiresContextualConfirmation = false,
  });
  final ConsentPurpose purpose;
  final String title;
  final String summary;
  final List<String> dataScope;
  final String defaultStateLabel;
  final bool canWithdraw;
  final bool requiresContextualConfirmation;
}

class ConsentPurposeRegistry {
  const ConsentPurposeRegistry({
    required this.heading,
    required this.summary,
    required this.purposes,
    required this.guardrails,
  });
  final String heading;
  final String summary;
  final List<ConsentPurposeDefinition> purposes;
  final List<String> guardrails;
}

class ConsentPurposeRegistryService {
  const ConsentPurposeRegistryService();
  ConsentPurposeRegistry buildRegistry() => const ConsentPurposeRegistry(
    heading: 'データ利用の設定',
    summary: '利用目的ごとに選べます。許可しなくてもQuest、Mission、Arcの基本機能は利用できます。',
    purposes: [
      ConsentPurposeDefinition(
        purpose: ConsentPurpose.arcPersonalization,
        title: 'Arcのパーソナライズ',
        summary: '過去のQuestやMission傾向から、Arcの提案を調整します。',
        dataScope: ['Quest DNA', 'Missionの進み方'],
        defaultStateLabel: '許可しない',
        canWithdraw: true,
      ),
      ConsentPurposeDefinition(
        purpose: ConsentPurpose.productImprovement,
        title: '品質改善',
        summary: 'Questra内部で機能品質の改善に利用します。',
        dataScope: ['機能利用状況', 'エラー傾向'],
        defaultStateLabel: '許可しない',
        canWithdraw: true,
      ),
      ConsentPurposeDefinition(
        purpose: ConsentPurpose.anonymousAnalytics,
        title: '匿名統計',
        summary: '個人を特定しない集計へ利用します。',
        dataScope: ['Stage', '進捗帯'],
        defaultStateLabel: '許可しない',
        canWithdraw: true,
      ),
      ConsentPurposeDefinition(
        purpose: ConsentPurpose.businessRecommendations,
        title: '支援情報',
        summary: 'Missionに合う企業・団体の支援情報を表示します。',
        dataScope: ['Mission支援分類'],
        defaultStateLabel: '許可しない',
        canWithdraw: true,
      ),
      ConsentPurposeDefinition(
        purpose: ConsentPurpose.businessSegmentAnalysis,
        title: '匿名の傾向分析',
        summary: '10人以上の匿名集計へ、許可された派生属性だけを利用します。',
        dataScope: ['Quest DNA派生属性'],
        defaultStateLabel: '許可しない',
        canWithdraw: true,
      ),
      ConsentPurposeDefinition(
        purpose: ConsentPurpose.personalDataSharing,
        title: '個人情報の共有',
        summary: '共有先と共有項目を確認した場面でのみ個別に選択します。',
        dataScope: ['確認画面で指定した情報のみ'],
        defaultStateLabel: '常に確認',
        canWithdraw: true,
        requiresContextualConfirmation: true,
      ),
    ],
    guardrails: [
      '目的ごとに選択',
      'いつでも撤回可能',
      'Arc会話とArc Memoryは企業へ提供しない',
      '採用、保険、信用評価へ無断転用しない',
    ],
  );
}
