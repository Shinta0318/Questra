import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/persistence/persistence_sync_state.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_providers.dart';
import 'package:questra/features/mission/mission_repository.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_providers.dart';
import 'package:questra/features/quest/quest_repository.dart';
import 'package:questra/features/trail/trail_sync_state.dart';
import 'package:questra/widgets/persistence_sync_banner.dart';

final _syncProvider =
    NotifierProvider<PersistenceSyncController, PersistenceSyncState>(
      PersistenceSyncController.new,
    );

void main() {
  testWidgets('保存成功通知は短時間で一度だけ閉じる', (tester) async {
    var dismissCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersistenceSyncBanner(
            state: const PersistenceSyncState(
              status: PersistenceSyncStatus.saved,
              message: 'Questを保存しました。',
              operation: PersistenceSyncOperation.save,
            ),
            successDuration: const Duration(milliseconds: 200),
            onDismiss: () => dismissCount++,
          ),
        ),
      ),
    );

    expect(find.text('Questを保存しました。'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Questを保存しました。'), findsNothing);
    expect(dismissCount, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(dismissCount, 1);
  });

  testWidgets('読込失敗だけに再試行操作を表示する', (tester) async {
    var retryCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersistenceSyncBanner(
            state: const PersistenceSyncState(
              status: PersistenceSyncStatus.failed,
              message: 'Questの読み込みに失敗しました。通信状態を確認してください。',
              operation: PersistenceSyncOperation.load,
            ),
            onRetry: () => retryCount++,
            onDismiss: () {},
          ),
        ),
      ),
    );

    expect(find.byTooltip('もう一度試す'), findsOneWidget);
    await tester.tap(find.byTooltip('もう一度試す'));
    expect(retryCount, 1);
    expect(tester.takeException(), isNull);
  });

  test('共通同期エラーは内部例外を利用者向け文面へ含めない', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(_syncProvider.notifier);

    controller.loading('保存しています...', operation: PersistenceSyncOperation.save);
    controller.failed(
      'Questの保存',
      StateError('postgres password=not-for-the-user'),
    );

    final state = container.read(_syncProvider);
    expect(state.status, PersistenceSyncStatus.failed);
    expect(state.operation, PersistenceSyncOperation.save);
    expect(state.message, 'Questの保存に失敗しました。通信状態を確認して、もう一度お試しください。');
    expect(state.message, isNot(contains('postgres')));
    expect(state.message, isNot(contains('password')));
  });

  test('Trail同期エラーも内部例外を表示しない', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(trailSyncControllerProvider.notifier);

    controller.loading('Trailを保存しています...', TrailSyncOperation.save);
    controller.failed(StateError('storage token=secret'));

    final state = container.read(trailSyncControllerProvider);
    expect(state.operation, TrailSyncOperation.save);
    expect(state.message, contains('もう一度お試しください'));
    expect(state.message, isNot(contains('token')));
    expect(state.message, isNot(contains('secret')));
  });

  test('QuestとMissionの通常読込成功は通知を残さない', () async {
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_SignedInAuthController.new),
        questRepositoryProvider.overrideWithValue(InMemoryQuestRepository()),
        missionRepositoryProvider.overrideWithValue(
          InMemoryMissionRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(questControllerProvider.notifier)
        .loadForUser('qst-412-user');
    expect(
      container.read(questSyncControllerProvider).status,
      PersistenceSyncStatus.idle,
    );

    await container.read(missionControllerProvider.notifier).loadForQuests(
      const ['quest-1'],
    );
    expect(
      container.read(missionSyncControllerProvider).status,
      PersistenceSyncStatus.idle,
    );
  });
}

class _SignedInAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    profile: UserProfile(
      id: 'qst-412-user',
      email: 'notification@example.invalid',
      nickname: 'Navigator',
      onboardingCompleted: true,
      legalAcceptanceCurrent: true,
    ),
  );
}
