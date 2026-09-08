import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/settings/connection_status_service.dart';
import 'package:questra/features/settings/widgets/connection_status_card.dart';

void main() {
  const service = ConnectionStatusService();

  test('configured session stays pending until Arc response is checked', () {
    final snapshot = service.build(
      remoteConfigured: true,
      authenticated: true,
      localMockPreview: false,
    );

    expect(snapshot.dataStorage.statusLabel, '利用できます');
    expect(snapshot.arcConversation.statusLabel, '応答確認待ち');
    expect(snapshot.arcConversation.statusLabel, isNot('確認済み'));
  });

  test('local preview is never presented as an online response', () {
    final snapshot = service.build(
      remoteConfigured: false,
      authenticated: true,
      localMockPreview: true,
    );

    expect(snapshot.dataStorage.state, ConnectionCapabilityState.preview);
    expect(snapshot.arcConversation.statusLabel, 'プレビュー応答');
    expect(snapshot.arcConversation.detail, contains('オンライン応答ではありません'));
  });

  testWidgets('action-required state offers an Arc verification route', (
    tester,
  ) async {
    var opened = false;
    final snapshot = service.build(
      remoteConfigured: true,
      authenticated: true,
      localMockPreview: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectionStatusCard(
            snapshot: snapshot,
            onOpenArc: () => opened = true,
          ),
        ),
      ),
    );

    expect(find.text('接続状態'), findsOneWidget);
    expect(find.text('応答確認待ち'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('connection_status_open_arc')));
    expect(opened, isTrue);
  });
}
