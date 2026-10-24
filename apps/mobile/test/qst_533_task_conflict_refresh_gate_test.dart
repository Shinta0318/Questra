import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/mission/mission_providers.dart';
import 'package:questra/features/mission/mission_repository.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/task/task_controller.dart';
import 'package:questra/features/task/task_model.dart';
import 'package:questra/features/task/task_mutation_banner.dart';
import 'package:questra/features/task/task_mutation_state.dart';
import 'package:questra/features/task/task_offline_queue_repository.dart';
import 'package:questra/features/task/task_providers.dart';
import 'package:questra/features/task/task_repository.dart';

void main() {
  test(
    'unresolved remote conflict blocks writes until Mission refresh',
    () async {
      final repository = _ConflictRepository();
      final missionRepository = InMemoryMissionRepository();
      await missionRepository.save(
        Mission(
          id: 'mission',
          questId: 'quest',
          questTitle: 'Quest',
          title: 'Mission',
          description: '進める',
          guideType: GuideType.route,
          difficulty: MissionDifficulty.easy,
          status: MissionStatus.todo,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_OwnerFixture.new),
          taskRepositoryProvider.overrideWithValue(repository),
          missionRepositoryProvider.overrideWithValue(missionRepository),
          taskOfflineQueueRepositoryProvider.overrideWithValue(
            InMemoryTaskOfflineQueueRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(taskControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      final original = await controller.addTask(_task('first'));
      await repository.updateWithVersion(
        original.copyWith(title: '別の端末の変更'),
        operationId: 'remote-edit',
      );
      repository.failReads = true;

      expect(await controller.start(original.id), isFalse);
      expect(
        container.read(taskMutationControllerProvider).needsConflictRefresh,
        isTrue,
      );
      container.read(taskMutationControllerProvider.notifier).clear();
      expect(
        container.read(taskMutationControllerProvider).needsConflictRefresh,
        isTrue,
      );
      await expectLater(controller.addTask(_task('second')), throwsStateError);
      expect(await controller.refreshConflict(), isFalse);
      expect(
        container.read(taskMutationControllerProvider).needsConflictRefresh,
        isTrue,
      );

      repository.failReads = false;
      expect(await controller.refreshConflict(), isTrue);
      expect(
        container.read(taskMutationControllerProvider).needsConflictRefresh,
        isFalse,
      );
      expect(container.read(taskControllerProvider).single.title, '別の端末の変更');
      expect((await controller.addTask(_task('second'))).id, 'second');
    },
  );

  testWidgets('unresolved conflict offers refresh but no dismiss', (
    tester,
  ) async {
    var refreshCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskMutationBanner(
            state: const TaskMutationState(
              status: TaskMutationStatus.conflict,
              message: '最新のTaskを読み込めませんでした。',
              conflictMissionIds: {'mission'},
            ),
            onRetry: () async {},
            onDiscard: () async {},
            onDismiss: () {},
            onRefreshConflict: () async {
              refreshCount++;
              return true;
            },
          ),
        ),
      ),
    );
    expect(find.byTooltip('閉じる'), findsNothing);
    await tester.tap(find.byTooltip('最新のTaskを再読み込み'));
    expect(refreshCount, 1);
  });

  testWidgets('conflict warning fits a compact screen at 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: TaskMutationBanner(
              state: const TaskMutationState(
                status: TaskMutationStatus.conflict,
                message: 'Taskが別の端末で更新されました。最新の内容を読み込めませんでした。再読み込みしてください。',
                conflictMissionIds: {'mission'},
              ),
              onRetry: () async {},
              onDiscard: () async {},
              onDismiss: () {},
              onRefreshConflict: () async => true,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('最新のTaskを再読み込み'), findsOneWidget);
  });
}

QuestraTask _task(String id) => QuestraTask(
  id: id,
  questId: 'quest',
  missionId: 'mission',
  title: '準備する',
  action: '必要な準備をする',
  doneCondition: '準備が終わった',
);

class _OwnerFixture extends AuthController {
  @override
  AuthState build() => const AuthState(
    profile: UserProfile(
      id: 'owner-a',
      email: 'owner-a@example.invalid',
      nickname: 'A',
    ),
  );
}

class _ConflictRepository extends InMemoryTaskRepository {
  bool failReads = false;

  @override
  bool get supportsAtomicCompletion => true;

  @override
  Future<List<QuestraTask>> findByMission(
    String missionId, {
    int limit = 50,
  }) async {
    if (failReads) throw StateError('network unavailable');
    return super.findByMission(missionId, limit: limit);
  }
}
