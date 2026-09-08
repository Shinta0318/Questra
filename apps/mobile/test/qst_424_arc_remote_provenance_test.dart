import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc/arc_chat_service.dart';
import 'package:questra/features/arc/arc_remote_status_controller.dart';
import 'package:questra/features/settings/connection_status_service.dart';

void main() {
  test(
    'remote response is verified only with an accepted source and trace',
    () {
      final response = SupabaseArcChatService.parseResponseData({
        'message': '一緒に航路を整えよう。',
        'source_type': 'gemini_interactions',
        'trace_id': 'trace_424-verified',
        'intent_type': 'quest_intent',
        'intent_confidence': 0.95,
        'safety_status': 'allowed',
        'quest_cta': {'show': true, 'reason': '複数の準備が必要'},
        'quest_suggestion': {
          'title': 'シンガポールを訪れる',
          'description': '希望に合う旅程で訪れる',
          'category': '旅行',
          'difficulty': 'normal',
        },
      }, sourceInput: 'シンガポールに行きたい');

      expect(response.deliveryMode, ArcChatDeliveryMode.remoteVerified);
      expect(response.traceId, 'trace_424-verified');
      expect(response.questSuggestion, isNotNull);
    },
  );

  test('fallback payload cannot expose Quest or route operations', () {
    final response = SupabaseArcChatService.parseResponseData({
      'message': '固定の代替回答',
      'source_type': 'arc_chat_fallback',
      'trace_id': 'trace-424-fallback',
      'intent_type': 'quest_intent',
      'intent_confidence': 1,
      'safety_status': 'allowed',
      'quest_cta': {'show': true, 'reason': 'untrusted'},
      'quest_suggestion': {
        'title': '保存してはいけないQuest',
        'description': 'fallback',
        'category': 'その他',
        'difficulty': 'normal',
      },
      'quest_changes': [
        {
          'id': 'unsafe-change',
          'kind': 'add_mission',
          'quest_id': 'quest-1',
          'title': '保存してはいけないMission',
        },
      ],
    }, sourceInput: '相談');

    expect(response.deliveryMode, ArcChatDeliveryMode.degraded);
    expect(response.questSuggestion, isNull);
    expect(response.questChanges, isEmpty);
    expect(response.showQuestCta, isFalse);
    expect(response.quickActions, contains('もう一度試す'));
  });

  test('invalid or foreign-looking trace fails closed', () {
    final response = SupabaseArcChatService.parseResponseData({
      'message': '応答',
      'source_type': 'gemini_interactions',
      'trace_id': '../../secret?token=value',
      'intent_type': 'quest_intent',
      'safety_status': 'allowed',
      'quest_cta': {'show': true, 'reason': 'untrusted'},
      'quest_suggestion': {
        'title': '保存してはいけないQuest',
        'description': 'invalid trace',
        'category': 'その他',
        'difficulty': 'normal',
      },
    }, sourceInput: '相談');

    expect(response.deliveryMode, ArcChatDeliveryMode.degraded);
    expect(response.traceId, isNull);
    expect(response.questSuggestion, isNull);
  });

  test('session provenance is in-memory and stale success is cleared', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(arcRemoteStatusProvider.notifier);

    controller.markVerified(
      traceId: 'trace-424',
      latencyClass: ArcRemoteLatencyClass.fast,
      checkedAt: DateTime.utc(2026, 9, 8, 1),
    );
    expect(container.read(arcRemoteStatusProvider).isVerified, isTrue);
    expect(container.read(arcRemoteStatusProvider).sourceClass, 'online');

    controller.markDegraded(failureReason: 'timeout');
    final degraded = container.read(arcRemoteStatusProvider);
    expect(degraded.responseState, ArcRemoteResponseState.degraded);
    expect(degraded.traceId, isNull);

    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);
    expect(
      restarted.read(arcRemoteStatusProvider).responseState,
      ArcRemoteResponseState.notChecked,
    );
  });

  test('Settings claims verification only after a remote success', () {
    const service = ConnectionStatusService();
    final pending = service.build(
      remoteConfigured: true,
      authenticated: true,
      localMockPreview: false,
    );
    final verified = service.build(
      remoteConfigured: true,
      authenticated: true,
      localMockPreview: false,
      arcRemoteStatus: ArcRemoteStatus(
        responseState: ArcRemoteResponseState.verified,
        sourceClass: 'online',
        checkedAt: DateTime.utc(2026, 9, 8),
        traceId: 'trace-424',
        latencyClass: ArcRemoteLatencyClass.normal,
      ),
    );
    final preview = service.build(
      remoteConfigured: false,
      authenticated: true,
      localMockPreview: true,
      arcRemoteStatus: const ArcRemoteStatus(
        responseState: ArcRemoteResponseState.preview,
        sourceClass: 'preview',
      ),
    );

    expect(pending.arcConversation.statusLabel, '応答確認待ち');
    expect(verified.arcConversation.statusLabel, '応答確認済み');
    expect(preview.arcConversation.statusLabel, 'プレビュー応答');
  });
}
