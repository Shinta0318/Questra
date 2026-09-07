enum SettingsSectionType {
  experience,
  planning,
  tutorial,
  trust,
  arcMemory,
  dataRequest,
  consent,
  feedback,
}

class SettingsSectionOverview {
  const SettingsSectionOverview({
    required this.type,
    required this.title,
    required this.summary,
    required this.statusLabel,
    required this.destination,
  });

  final SettingsSectionType type;
  final String title;
  final String summary;
  final String statusLabel;
  final String destination;
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

  SettingsInformationArchitecture buildOverview({
    bool remotePersistenceConnected = false,
  }) {
    return SettingsInformationArchitecture(
      heading: '設定メニュー',
      summary: '変更したい項目を選んでください。',
      sections: [
        const SettingsSectionOverview(
          type: SettingsSectionType.experience,
          title: '操作と演出',
          summary: 'アニメーション、触覚、効果音、スワイプを調整します。',
          statusLabel: '設定できます',
          destination: 'experience',
        ),
        const SettingsSectionOverview(
          type: SettingsSectionType.planning,
          title: '航路の条件',
          summary: '曜日ごとの時間や、Arcが計画に使う条件を設定します。',
          statusLabel: '設定できます',
          destination: 'planning',
        ),
        const SettingsSectionOverview(
          type: SettingsSectionType.tutorial,
          title: 'Arcチュートリアル',
          summary: 'Home、Arc、Questの基本操作をもう一度確認します。',
          statusLabel: '再表示できます',
          destination: 'tutorial',
        ),
        const SettingsSectionOverview(
          type: SettingsSectionType.trust,
          title: 'データとプライバシー',
          summary: '保存範囲、Arcの生成機能、データ保護の方針を確認します。',
          statusLabel: '確認できます',
          destination: 'privacy',
        ),
        const SettingsSectionOverview(
          type: SettingsSectionType.arcMemory,
          title: 'Arc Memory',
          summary: 'Arcが参照する記憶を確認・削除します。',
          statusLabel: '利用できます',
          destination: '/settings/arc-memory',
        ),
        SettingsSectionOverview(
          type: SettingsSectionType.dataRequest,
          title: '自分のデータ',
          summary: remotePersistenceConnected
              ? 'エクスポート、訂正、削除を管理します。'
              : 'この端末のデータを確認します。アカウント操作には接続が必要です。',
          statusLabel: remotePersistenceConnected ? '利用できます' : '端末内のみ',
          destination: '/settings/data-rights',
        ),
        const SettingsSectionOverview(
          type: SettingsSectionType.consent,
          title: '目的別の同意',
          summary: 'Arcの品質改善や外部連携に使う範囲を選びます。',
          statusLabel: '設定できます',
          destination: 'consent',
        ),
        const SettingsSectionOverview(
          type: SettingsSectionType.feedback,
          title: 'フィードバック',
          summary: 'Betaで気づいた点を端末内でまとめます。',
          statusLabel: '利用できます',
          destination: '/feedback',
        ),
      ],
    );
  }
}
