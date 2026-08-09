enum DataRequestType { export, deletion, correction, withdrawal }

class DataRequestCopy {
  const DataRequestCopy({
    required this.type,
    required this.title,
    required this.summary,
    required this.scope,
    required this.statusLabel,
  });

  final DataRequestType type;
  final String title;
  final String summary;
  final List<String> scope;
  final String statusLabel;
}

class DataRequestCopyReview {
  const DataRequestCopyReview({
    required this.heading,
    required this.summary,
    required this.requests,
    required this.safetyNotes,
  });

  final String heading;
  final String summary;
  final List<DataRequestCopy> requests;
  final List<String> safetyNotes;
}

class DataRequestCopyService {
  const DataRequestCopyService();

  DataRequestCopyReview buildReview() {
    return const DataRequestCopyReview(
      heading: 'データリクエスト',
      summary:
          'Questraの挑戦データは本人のものです。Betaでは実処理の前に、削除・エクスポート・訂正・同意撤回の範囲を分かりやすく確認できるようにします。',
      requests: [
        DataRequestCopy(
          type: DataRequestType.export,
          title: 'データエクスポート',
          summary:
              '自分のQuest、Mission、Task、Trail、Arc Memory、Profile情報を取り出すための導線です。',
          scope: ['Quest', 'Mission', 'Task', 'Trail', 'Arc Memory', 'Profile'],
          statusLabel: '利用可能',
        ),
        DataRequestCopy(
          type: DataRequestType.deletion,
          title: 'データ削除リクエスト',
          summary: '不要になった挑戦データやアカウント関連データの削除を依頼するための導線です。',
          scope: ['Quest', 'Mission', 'Task', 'Trail', 'Media', 'Arc Memory'],
          statusLabel: '利用可能',
        ),
        DataRequestCopy(
          type: DataRequestType.correction,
          title: '訂正リクエスト',
          summary: 'Arcの推定、タグ、記憶、プロフィール情報に誤りがある場合に知らせる導線です。',
          scope: ['Arc推定', 'Tag', 'Arc Memory', 'Profile'],
          statusLabel: '準備中',
        ),
        DataRequestCopy(
          type: DataRequestType.withdrawal,
          title: '同意の見直し',
          summary: '将来のQuest支援、分析、外部連携に対する同意を目的別に見直す導線です。',
          scope: ['Quest Support', '分析', '外部連携'],
          statusLabel: '設定する',
        ),
      ],
      safetyNotes: [
        '削除・エクスポートは無料で利用できる基本機能として扱う',
        '企業支援や広告のために個別データを無断利用しない',
        '本人確認と誤削除防止を両立する',
        '実装前にPrivacy Policyと運用手順を更新する',
      ],
    );
  }
}
