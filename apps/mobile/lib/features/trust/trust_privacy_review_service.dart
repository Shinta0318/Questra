enum TrustPrivacyArea {
  journeyData,
  arcMemory,
  aiTransparency,
  questSupport,
  ownerBoundary,
}

class TrustPrivacyReviewItem {
  const TrustPrivacyReviewItem({
    required this.area,
    required this.title,
    required this.summary,
    required this.statusLabel,
    required this.userControl,
  });

  final TrustPrivacyArea area;
  final String title;
  final String summary;
  final String statusLabel;
  final String userControl;
}

class TrustPrivacyReview {
  const TrustPrivacyReview({
    required this.heading,
    required this.summary,
    required this.items,
    required this.betaNotices,
    required this.legalStatus,
    required this.futureActions,
  });

  final String heading;
  final String summary;
  final List<TrustPrivacyReviewItem> items;
  final List<String> betaNotices;
  final String legalStatus;
  final List<String> futureActions;
}

class TrustPrivacyReviewService {
  const TrustPrivacyReviewService();

  TrustPrivacyReview buildReview() {
    return const TrustPrivacyReview(
      heading: 'データとプライバシー',
      summary:
          'Questraは、Questを進めるために必要なデータだけを扱います。保存される内容と、Arcの生成時に外部で処理される内容を分けて説明します。',
      items: [
        TrustPrivacyReviewItem(
          area: TrustPrivacyArea.journeyData,
          title: 'Quest / Mission / Task / Trail',
          summary:
              '接続済みのBeta環境では、Profileと挑戦データをSupabaseへ保存します。未接続のデモ環境では端末上の一時データとして動作します。',
          statusLabel: '非公開が既定',
          userControl: 'Guildや企業へ自動共有しません。公開範囲を変える機能は現在未提供です。',
        ),
        TrustPrivacyReviewItem(
          area: TrustPrivacyArea.arcMemory,
          title: 'Arc Memory',
          summary:
              'Quest、Mission、Task、Trail、Reflection、Arcとの対話から、旅路を支える記憶を作成・保存する場合があります。',
          statusLabel: '本人専用',
          userControl: 'Guildや企業支援へ自動共有しません。確認・個別削除は現在プレビュー段階です。',
        ),
        TrustPrivacyReviewItem(
          area: TrustPrivacyArea.aiTransparency,
          title: 'Arcの生成機能',
          summary:
              '外部生成が有効な場合、入力、直近の会話、進行中のQuest、最近のMission・Task・Trail、選ばれたArc MemoryをSupabase Edge Function経由でGemini APIへ送ります。OpenAI互換経路は運営側が明示設定した場合だけ利用します。',
          statusLabel: '外部処理あり',
          userControl:
              'Geminiへのrequest保存は無効化しています。未設定・失敗時は端末内の応答へ切り替わります。生成内容は誤ることがあるため、重要な判断では確認してください。',
        ),
        TrustPrivacyReviewItem(
          area: TrustPrivacyArea.questSupport,
          title: 'Quest支援',
          summary: '企業支援は広告ではなく、Quest前進の支援として透明に表示します。',
          statusLabel: 'Betaでは未接続',
          userControl: '支援表示の非表示とフィードバック導線を追加予定です。',
        ),
        TrustPrivacyReviewItem(
          area: TrustPrivacyArea.ownerBoundary,
          title: 'RLS / 所有者管理',
          summary: 'ユーザーごとのデータを分離し、他のユーザーのPrivateデータを表示しない設計を前提にします。',
          statusLabel: '検証対象',
          userControl: '東京リージョンのBeta環境でRLSを検証しています。実アカウント分離の確認を継続します。',
        ),
      ],
      betaNotices: [
        'Betaフィードバックはレポートをクリップボードへコピーするだけで、自動送信しません。',
        'クラッシュ情報の外部自動送信は無効です。障害証跡はプライバシー確認後に導入判断します。',
        'データのエクスポート、アカウント削除、同意撤回の実処理は、このビルドではまだ利用できません。',
      ],
      legalStatus: 'これは内部Beta向けの説明です。利用規約とプライバシーポリシーは草案で、外部配布前に人による法務確認が必要です。',
      futureActions: ['データ削除リクエスト', 'データエクスポート', 'Arc Memory管理', 'AI提案の訂正報告'],
    );
  }
}
