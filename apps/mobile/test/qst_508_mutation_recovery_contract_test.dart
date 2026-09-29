import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/persistence/persistence_sync_state.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/mission/mission_providers.dart';
import 'package:questra/features/mission/mission_repository.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/quest/quest_providers.dart';
import 'package:questra/features/quest/quest_repository.dart';
import 'package:questra/features/trail/trail_sync_state.dart';
import 'package:questra/widgets/persistence_sync_banner.dart';

import 'support/fixture_quest_controller.dart';

void main() {
  test('古い成功応答は新しい失敗操作の再試行を消さない', () async {
    final slot = PersistenceRetrySlot();
    final older = slot.begin();
    final newer = slot.begin();
    var retried = false;

    slot.remember(newer, () async => retried = true);
    slot.resolve(older);

    expect(slot.hasPending, isTrue);
    expect(await slot.retry(), isTrue);
    expect(retried, isTrue);
    expect(slot.hasPending, isFalse);
  });

  test('Quest保存失敗は変更を保持し、同じQuestを再試行できる', () async {
    final repository = _FlakyQuestRepository();
    final quest = Quest(
      id: 'quest-retry',
      title: 'シンガポールへ行く',
      description: '現地の文化と食を体験する',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
    );
    await repository.save(ownerId: 'qst-508-user', quest: quest);
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_SignedInAuthController.new),
        questRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(questControllerProvider.notifier);
    await controller.loadForUser('qst-508-user');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    repository.saveFailures = 1;
    controller.update(quest.copyWith(description: '現地の文化、食、街歩きを体験する'));
    await _waitForStatus(
      () => container.read(questSyncControllerProvider),
      PersistenceSyncStatus.failed,
    );

    final failed = container.read(questSyncControllerProvider);
    expect(failed.canRetry, isTrue);
    expect(failed.inputPreserved, isTrue);
    expect(failed.message, contains('変更内容は保持'));
    expect(controller.findById(quest.id)?.description, contains('街歩き'));

    expect(await controller.retryPending(), isTrue);
    expect(
      container.read(questSyncControllerProvider).status,
      isNot(PersistenceSyncStatus.failed),
    );
    expect(repository.saved[quest.id]?.description, contains('街歩き'));
  });

  test('Mission保存と削除の失敗は復元後に再試行できる', () async {
    final repository = _FlakyMissionRepository();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_SignedInAuthController.new),
        questControllerProvider.overrideWith(FixtureQuestController.new),
        missionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final quest = container.read(questControllerProvider).first;
    final controller = container.read(missionControllerProvider.notifier);
    await controller.loadForQuests([quest.id]);
    final mission = controller.addMissionDraft(
      quest: quest,
      title: '旅行日程を決める',
      description: '同行者と候補日を確認する',
      guideType: GuideType.route,
      difficulty: MissionDifficulty.easy,
    );
    await _waitForStatus(
      () => container.read(missionSyncControllerProvider),
      PersistenceSyncStatus.saved,
    );

    repository.saveFailures = 1;
    controller.updateMission(mission.copyWith(description: '同行者と3つの候補日を確認する'));
    await _waitForStatus(
      () => container.read(missionSyncControllerProvider),
      PersistenceSyncStatus.failed,
    );
    expect(container.read(missionSyncControllerProvider).canRetry, isTrue);
    expect(
      container.read(missionControllerProvider).single.description,
      contains('3つ'),
    );
    expect(await controller.retryPending(), isTrue);
    expect(repository.saved[mission.id]?.description, contains('3つ'));

    repository.deleteFailures = 1;
    controller.removeMission(mission.id);
    await _waitForStatus(
      () => container.read(missionSyncControllerProvider),
      PersistenceSyncStatus.failed,
    );
    expect(
      container.read(missionControllerProvider).map((item) => item.id),
      contains(mission.id),
    );
    expect(await controller.retryPending(), isTrue);
    expect(
      container.read(missionControllerProvider).map((item) => item.id),
      isNot(contains(mission.id)),
    );
    expect(repository.saved.containsKey(mission.id), isFalse);
  });

  test('Trailは読み込みのみ共通再試行、編集失敗は入力保持を示す', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(trailSyncControllerProvider.notifier);

    controller.loading('Trailを読み込んでいます...', TrailSyncOperation.load);
    controller.failed(StateError('XMLHttpRequest error'));
    var state = container.read(trailSyncControllerProvider);
    expect(state.retryAvailable, isTrue);
    expect(state.inputPreserved, isFalse);
    expect(state.offline, isTrue);

    controller.loading('Trailを保存しています...', TrailSyncOperation.save);
    controller.failed(StateError('temporary failure'));
    state = container.read(trailSyncControllerProvider);
    expect(state.retryAvailable, isFalse);
    expect(state.inputPreserved, isTrue);
    expect(state.message, contains('入力内容は保持'));
  });

  testWidgets('再試行可能な通知は誤って閉じられない', (tester) async {
    var retryCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersistenceSyncBanner(
            state: const PersistenceSyncState(
              status: PersistenceSyncStatus.failed,
              message: '保存できませんでした。変更内容は保持されています。',
              operation: PersistenceSyncOperation.save,
              retryAvailable: true,
              inputPreserved: true,
            ),
            onRetry: () => retryCount++,
            onDismiss: () {},
          ),
        ),
      ),
    );

    expect(find.byTooltip('通知を閉じる'), findsNothing);
    await tester.tap(find.byTooltip('もう一度試す'));
    expect(retryCount, 1);
  });
}

Future<void> _waitForStatus(
  PersistenceSyncState Function() readState,
  PersistenceSyncStatus status,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (readState().status == status) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for $status; current=${readState().status}');
}

class _SignedInAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    profile: UserProfile(
      id: 'qst-508-user',
      email: 'qst508@example.invalid',
      nickname: 'Navigator',
      onboardingCompleted: true,
      legalAcceptanceCurrent: true,
    ),
  );
}

class _FlakyQuestRepository extends InMemoryQuestRepository {
  int saveFailures = 0;
  final Map<String, Quest> saved = {};

  @override
  Future<Quest> save({required String ownerId, required Quest quest}) async {
    if (saveFailures > 0) {
      saveFailures--;
      throw StateError('temporary failure');
    }
    final result = await super.save(ownerId: ownerId, quest: quest);
    saved[result.id] = result;
    return result;
  }
}

class _FlakyMissionRepository extends InMemoryMissionRepository {
  int saveFailures = 0;
  int deleteFailures = 0;
  final Map<String, Mission> saved = {};

  @override
  Future<Mission> save(Mission mission) async {
    if (saveFailures > 0) {
      saveFailures--;
      throw StateError('temporary failure');
    }
    final result = await super.save(mission);
    saved[result.id] = result;
    return result;
  }

  @override
  Future<void> delete(String missionId) async {
    if (deleteFailures > 0) {
      deleteFailures--;
      throw StateError('temporary failure');
    }
    await super.delete(missionId);
    saved.remove(missionId);
  }
}
