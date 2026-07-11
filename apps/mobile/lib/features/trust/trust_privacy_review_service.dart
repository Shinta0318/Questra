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
    required this.futureActions,
  });

  final String heading;
  final String summary;
  final List<TrustPrivacyReviewItem> items;
  final List<String> futureActions;
}

class TrustPrivacyReviewService {
  const TrustPrivacyReviewService();

  TrustPrivacyReview buildReview() {
    return const TrustPrivacyReview(
      heading: 'Trust & Privacy',
      summary: 'Questraでは、挑戦データを本人の意思と同意を前提に扱います。Arcの記憶や推薦も、必要な範囲に絞って透明に説明します。',
      items: [
        TrustPrivacyReviewItem(
          area: TrustPrivacyArea.journeyData,
          title: 'Quest / Mission / Trail',
          summary: '挑戦の進行に必要なデータだけを扱い、Privateを安全な既定値にします。',
          statusLabel: '所有者境界あり',
          userControl: '今後、閲覧・訂正・削除・エクスポート導線を拡張します。',
        ),
        TrustPrivacyReviewItem(
          area: TrustPrivacyArea.arcMemory,
          title: 'Arc Memory',
          summary: 'Arcが旅路を理解するための記憶です。Guildや企業支援へ勝手に共有しません。',
          statusLabel: '本人専用',
          userControl: '重要な記憶の確認と削除導線を強化予定です。',
        ),
        TrustPrivacyReviewItem(
          area: TrustPrivacyArea.aiTransparency,
          title: 'Arcの生成・推定',
          summary: 'Arcが生成した提案や推定は、理由を説明できる形で扱います。',
          statusLabel: '説明可能性を優先',
          userControl: '誤りの報告と訂正導線を追加予定です。',
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
          userControl: 'Beta前にRLS検証と実クラウド環境確認を継続します。',
        ),
      ],
      futureActions: ['データ削除リクエスト', 'データエクスポート', 'Arc Memory管理', 'AI提案の訂正報告'],
    );
  }
}
