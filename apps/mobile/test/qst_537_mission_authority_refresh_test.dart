import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/mission/mission_providers.dart';
import 'package:questra/features/mission/mission_repository.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/task/task_controller.dart';
import 'package:questra/features/task/task_model.dart';
import 'package:questra/features/task/task_offline_queue_repository.dart';
import 'package:questra/features/task/task_providers.dart';
import 'package:questra/features/task/task_repository.dart';

void main() {
  test(
    're-completion on another device does not restore Mission approval',
    () async {
      final tasks = _RemoteTaskRepository();
      final missions = _MissionFixtureRepository();
      await tasks.save(_task(version: 5));
      await missions.save(_mission(confirmed: true));
      final container = _container(tasks, missions);
      addTearDown(container.dispose);
      final controller = container.read(taskControllerProvider.notifier);
      await controller.loadForQuestIds(['quest-537']);
      expect(
        container.read(missionControllerProvider).single.status,
        MissionStatus.completed,
      );

      await tasks.save(_task(version: 7));
      await missions.save(_mission(confirmed: false));
      expect(await controller.refreshMissionAuthority('mission-537'), isTrue);
      expect(container.read(taskControllerProvider).single.version, 7);
      final mission = container.read(missionControllerProvider).single;
      expect(mission.successConfirmedAt, isNull);
      expect(mission.status, MissionStatus.todo);
      expect(
        container
            .read(missionControllerProvider.notifier)
            .needsAuthorityRefresh(mission.id),
        isFalse,
      );
    },
  );

  test(
    'failed Mission fetch hides old confirmation until coupled retry',
    () async {
      final tasks = _RemoteTaskRepository();
      final missions = _MissionFixtureRepository();
      await tasks.save(_task(version: 5));
      await missions.save(_mission(confirmed: true));
      final container = _container(tasks, missions);
      addTearDown(container.dispose);
      final controller = container.read(taskControllerProvider.notifier);
      await controller.loadForQuestIds(['quest-537']);

      missions.failFindByIds = true;
      expect(await controller.refreshMissionAuthority('mission-537'), isFalse);
      final missionController = container.read(
        missionControllerProvider.notifier,
      );
      expect(missionController.needsAuthorityRefresh('mission-537'), isTrue);
      expect(
        container.read(missionControllerProvider).single.successConfirmedAt,
        isNull,
      );
      expect(
        missionController.confirmMissionSuccess(
          'mission-537',
          allRequiredTasksCompleted: true,
        ),
        isFalse,
      );

      missions.failFindByIds = false;
      await missions.save(_mission(confirmed: false));
      expect(await controller.refreshMissionAuthority('mission-537'), isTrue);
      expect(missionController.needsAuthorityRefresh('mission-537'), isFalse);
      expect(
        container.read(missionControllerProvider).single.status,
        MissionStatus.todo,
      );
    },
  );

  test(
    'older Mission load cannot overwrite a newer coupled snapshot',
    () async {
      final missions = _MissionFixtureRepository();
      await missions.save(_mission(confirmed: true));
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_SwitchableOwner.new),
          missionRepositoryProvider.overrideWithValue(missions),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(missionControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      final held = Completer<List<Mission>>();
      missions.heldQuestLoad = held;
      final staleLoad = controller.loadForQuests(['quest-537']);
      await Future<void>.delayed(Duration.zero);

      controller.applyAuthoritativeSnapshots([_mission(confirmed: false)]);
      held.complete([_mission(confirmed: true)]);
      await staleLoad;
      expect(
        container.read(missionControllerProvider).single.successConfirmedAt,
        isNull,
      );
    },
  );

  test(
    'owner switch discards an in-flight Mission authority response',
    () async {
      final tasks = _RemoteTaskRepository();
      final missions = _MissionFixtureRepository();
      await tasks.save(_task(version: 5));
      await missions.save(_mission(confirmed: true));
      final container = _container(tasks, missions, withOwner: true);
      addTearDown(container.dispose);
      final controller = container.read(taskControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      final held = Completer<List<Mission>>();
      missions.heldIdLoad = held;
      final load = controller.loadForQuestIds(['quest-537']);
      await Future<void>.delayed(Duration.zero);

      (container.read(authControllerProvider.notifier) as _SwitchableOwner)
          .switchOwner();
      held.complete([_mission(confirmed: true)]);
      await load;
      expect(container.read(taskControllerProvider), isEmpty);
      expect(container.read(missionControllerProvider), isEmpty);
    },
  );
}

ProviderContainer _container(
  _RemoteTaskRepository tasks,
  _MissionFixtureRepository missions, {
  bool withOwner = false,
}) => ProviderContainer(
  overrides: [
    if (withOwner) authControllerProvider.overrideWith(_SwitchableOwner.new),
    taskRepositoryProvider.overrideWithValue(tasks),
    missionRepositoryProvider.overrideWithValue(missions),
    taskOfflineQueueRepositoryProvider.overrideWithValue(
      InMemoryTaskOfflineQueueRepository(),
    ),
  ],
);

QuestraTask _task({required int version}) => QuestraTask(
  id: 'task-537',
  questId: 'quest-537',
  missionId: 'mission-537',
  title: '準備する',
  action: '具体的な準備をする',
  doneCondition: '準備を確認した',
  status: TaskStatus.completed,
  completedAt: DateTime.utc(2026, 10, 4),
  version: version,
);

Mission _mission({required bool confirmed}) => Mission(
  id: 'mission-537',
  questId: 'quest-537',
  questTitle: 'QST-537 Quest',
  title: '準備を整える',
  description: '準備を確認する',
  guideType: GuideType.route,
  difficulty: MissionDifficulty.easy,
  status: confirmed ? MissionStatus.completed : MissionStatus.todo,
  progressPercent: 100,
  successConfirmedAt: confirmed ? DateTime.utc(2026, 10, 4) : null,
);

class _RemoteTaskRepository extends InMemoryTaskRepository {
  @override
  bool get supportsAtomicCompletion => true;
}

class _MissionFixtureRepository extends InMemoryMissionRepository {
  bool failFindByIds = false;
  Completer<List<Mission>>? heldIdLoad;
  Completer<List<Mission>>? heldQuestLoad;

  @override
  Future<List<Mission>> findByIds(List<String> missionIds) {
    if (failFindByIds) throw StateError('network unavailable');
    final held = heldIdLoad;
    if (held != null) {
      heldIdLoad = null;
      return held.future;
    }
    return super.findByIds(missionIds);
  }

  @override
  Future<List<Mission>> findManyByQuestIds(
    List<String> questIds, {
    int limit = 80,
  }) {
    final held = heldQuestLoad;
    if (held != null) {
      heldQuestLoad = null;
      return held.future;
    }
    return super.findManyByQuestIds(questIds, limit: limit);
  }
}

class _SwitchableOwner extends AuthController {
  @override
  AuthState build() => const AuthState(
    profile: UserProfile(
      id: 'owner-a',
      email: 'owner-a@example.invalid',
      nickname: 'A',
    ),
  );

  void switchOwner() {
    state = const AuthState(
      profile: UserProfile(
        id: 'owner-b',
        email: 'owner-b@example.invalid',
        nickname: 'B',
      ),
    );
  }
}
