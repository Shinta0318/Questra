enum ConsentPurpose {
  questSupport,
  productAnalytics,
  aiQualityReview,
  externalConnection,
}

class ConsentPurposeDefinition {
  const ConsentPurposeDefinition({
    required this.purpose,
    required this.title,
    required this.summary,
    required this.dataScope,
    required this.defaultStateLabel,
    required this.canWithdraw,
  });

  final ConsentPurpose purpose;
  final String title;
  final String summary;
  final List<String> dataScope;
  final String defaultStateLabel;
  final bool canWithdraw;
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

  ConsentPurposeRegistry buildRegistry() {
    return const ConsentPurposeRegistry(
      heading: '目的別の同意',
      summary:
          'Questraでは、包括同意だけで個別のQuestデータを別目的へ転用しません。将来の連携は目的別に説明し、撤回できる形で扱います。',
      purposes: [
        ConsentPurposeDefinition(
          purpose: ConsentPurpose.questSupport,
          title: 'Quest支援',
          summary: 'ユーザーのQuestに合う支援を透明に紹介するための同意です。',
          dataScope: ['Quest DNA', 'Mission状況', 'Trail要約'],
          defaultStateLabel: 'Future opt-in',
          canWithdraw: true,
        ),
        ConsentPurposeDefinition(
          purpose: ConsentPurpose.productAnalytics,
          title: 'プロダクト改善分析',
          summary: '個人を識別しない形で、使いやすさや不具合を改善するための同意です。',
          dataScope: ['画面利用状況', 'クラッシュ情報', '機能利用傾向'],
          defaultStateLabel: 'Design required',
          canWithdraw: true,
        ),
        ConsentPurposeDefinition(
          purpose: ConsentPurpose.aiQualityReview,
          title: 'Arc品質改善',
          summary: 'Arcの提案品質や安全性を見直すための同意です。',
          dataScope: ['Arc応答', '採否', '誤り報告'],
          defaultStateLabel: 'Design required',
          canWithdraw: true,
        ),
        ConsentPurposeDefinition(
          purpose: ConsentPurpose.externalConnection,
          title: '外部連携',
          summary: '将来のイベント、Marketplace、Passportなどへ接続するための同意です。',
          dataScope: ['公開範囲', '参加履歴', '連携先条件'],
          defaultStateLabel: 'Future opt-in',
          canWithdraw: true,
        ),
      ],
      guardrails: [
        '同意は目的別に分ける',
        '撤回できる導線を用意する',
        'スポンサー関係は明示する',
        '採用、保険、信用評価へ無断転用しない',
      ],
    );
  }
}
