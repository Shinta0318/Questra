import '../arc/arc_remote_status_controller.dart';

enum ConnectionCapabilityState {
  available,
  actionRequired,
  preview,
  unavailable,
}

class ConnectionCapability {
  const ConnectionCapability({
    required this.title,
    required this.detail,
    required this.statusLabel,
    required this.state,
  });

  final String title;
  final String detail;
  final String statusLabel;
  final ConnectionCapabilityState state;
}

class ConnectionStatusSnapshot {
  const ConnectionStatusSnapshot({
    required this.summary,
    required this.dataStorage,
    required this.arcConversation,
  });

  final String summary;
  final ConnectionCapability dataStorage;
  final ConnectionCapability arcConversation;
}

class ConnectionStatusService {
  const ConnectionStatusService();

  ConnectionStatusSnapshot build({
    required bool remoteConfigured,
    required bool authenticated,
    required bool localMockPreview,
    ArcRemoteStatus arcRemoteStatus = const ArcRemoteStatus(),
  }) {
    if (remoteConfigured && authenticated) {
      if (arcRemoteStatus.responseState == ArcRemoteResponseState.verified) {
        return const ConnectionStatusSnapshot(
          summary: 'オンライン保存とArcの応答を、この起動中に確認できました。',
          dataStorage: ConnectionCapability(
            title: 'データ保存',
            detail: 'このアカウントへQuestやTrailを保存できます。',
            statusLabel: '利用できます',
            state: ConnectionCapabilityState.available,
          ),
          arcConversation: ConnectionCapability(
            title: 'Arcとの相談',
            detail: 'この起動中にオンライン応答を確認しました。',
            statusLabel: '応答確認済み',
            state: ConnectionCapabilityState.available,
          ),
        );
      }
      if (arcRemoteStatus.responseState == ArcRemoteResponseState.degraded) {
        return const ConnectionStatusSnapshot(
          summary: 'データ保存は利用できますが、Arcのオンライン応答は再確認が必要です。',
          dataStorage: ConnectionCapability(
            title: 'データ保存',
            detail: 'このアカウントへQuestやTrailを保存できます。',
            statusLabel: '利用できます',
            state: ConnectionCapabilityState.available,
          ),
          arcConversation: ConnectionCapability(
            title: 'Arcとの相談',
            detail: '前回はオンライン応答を確認できませんでした。入力内容は保持されています。',
            statusLabel: '再確認が必要',
            state: ConnectionCapabilityState.actionRequired,
          ),
        );
      }
      return const ConnectionStatusSnapshot(
        summary: 'オンライン機能を使う準備ができています。Arcの応答は会話画面で確認できます。',
        dataStorage: ConnectionCapability(
          title: 'データ保存',
          detail: 'このアカウントへQuestやTrailを保存できます。',
          statusLabel: '利用できます',
          state: ConnectionCapabilityState.available,
        ),
        arcConversation: ConnectionCapability(
          title: 'Arcとの相談',
          detail: '準備はできています。Arcで一度話して、オンライン応答を確認してください。',
          statusLabel: '応答確認待ち',
          state: ConnectionCapabilityState.actionRequired,
        ),
      );
    }

    if (remoteConfigured) {
      return const ConnectionStatusSnapshot(
        summary: 'オンライン機能を使うにはログインが必要です。',
        dataStorage: ConnectionCapability(
          title: 'データ保存',
          detail: 'ログインすると、このアカウントへ保存できます。',
          statusLabel: 'ログインが必要',
          state: ConnectionCapabilityState.actionRequired,
        ),
        arcConversation: ConnectionCapability(
          title: 'Arcとの相談',
          detail: 'ログイン後にオンライン応答を利用できます。',
          statusLabel: 'ログインが必要',
          state: ConnectionCapabilityState.actionRequired,
        ),
      );
    }

    if (localMockPreview) {
      return const ConnectionStatusSnapshot(
        summary: '現在は端末内のプレビューです。オンライン機能の確認結果にはなりません。',
        dataStorage: ConnectionCapability(
          title: 'データ保存',
          detail: 'この端末のプレビュー内だけに保存します。',
          statusLabel: 'プレビュー',
          state: ConnectionCapabilityState.preview,
        ),
        arcConversation: ConnectionCapability(
          title: 'Arcとの相談',
          detail: '固定のプレビュー応答です。オンライン応答ではありません。',
          statusLabel: 'プレビュー応答',
          state: ConnectionCapabilityState.preview,
        ),
      );
    }

    return const ConnectionStatusSnapshot(
      summary: 'オンライン機能を利用するための接続設定がありません。',
      dataStorage: ConnectionCapability(
        title: 'データ保存',
        detail: 'オンライン保存は利用できません。',
        statusLabel: '利用できません',
        state: ConnectionCapabilityState.unavailable,
      ),
      arcConversation: ConnectionCapability(
        title: 'Arcとの相談',
        detail: 'オンライン応答は利用できません。',
        statusLabel: '利用できません',
        state: ConnectionCapabilityState.unavailable,
      ),
    );
  }
}
