enum SettingsSectionType { tutorial, trust, arcMemory, dataRequest, consent }

class SettingsSectionOverview {
  const SettingsSectionOverview({
    required this.type,
    required this.title,
    required this.summary,
    required this.statusLabel,
  });

  final SettingsSectionType type;
  final String title;
  final String summary;
  final String statusLabel;
}

class SettingsInformationArchitecture {
  const SettingsInformationArchitecture({
    required this.heading,
    required this.summary,
    required this.sections,
  });

  final String heading;
  final String summary;
  final List<SettingsSectionOverview> sections;
}

class SettingsInformationArchitectureService {
  const SettingsInformationArchitectureService();

  SettingsInformationArchitecture buildOverview() {
    return const SettingsInformationArchitecture(
      heading: '設定ガイド',
      summary: '設定では、Arcの使い方、信頼とプライバシー、Arc Memory、データリクエスト、目的別同意を順番に確認できます。',
      sections: [
        SettingsSectionOverview(
          type: SettingsSectionType.tutorial,
          title: 'Arcチュートリアル',
          summary: 'Home、Arc、Questの基本導線をもう一度確認します。',
          statusLabel: 'もう一度見る',
        ),
        SettingsSectionOverview(
          type: SettingsSectionType.trust,
          title: '信頼とプライバシー',
          summary: '挑戦データ、Arcの生成・推定、所有者境界の原則を確認します。',
          statusLabel: '確認する',
        ),
        SettingsSectionOverview(
          type: SettingsSectionType.arcMemory,
          title: 'Arc Memory',
          summary: 'Arcが覚える記憶カテゴリと将来の管理操作を確認します。',
          statusLabel: '確認する',
        ),
        SettingsSectionOverview(
          type: SettingsSectionType.dataRequest,
          title: 'データリクエスト',
          summary: '削除、エクスポート、訂正、同意見直しの予定導線を確認します。',
          statusLabel: '準備中',
        ),
        SettingsSectionOverview(
          type: SettingsSectionType.consent,
          title: '目的別の同意',
          summary: 'Quest支援、分析、Arc品質改善、外部連携を目的別に確認します。',
          statusLabel: '今後選択可能',
        ),
      ],
    );
  }
}
