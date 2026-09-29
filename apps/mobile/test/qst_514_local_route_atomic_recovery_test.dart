import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/quest/route_replanning_controller.dart';
import 'package:questra/features/quest/route_replanning_model.dart';
import 'package:questra/features/quest/route_replanning_repository.dart';
import 'package:questra/features/quest/route_snapshot_service.dart';
import 'package:questra/features/task/task_controller.dart';
import 'package:questra/features/task/task_model.dart';

void main() {
  setUp(() => _TaskFixtureController.failRestore = false);

  test('proposal remains pending until every local change succeeds', () async {
    final repository = _RecordingRepository(blockFinalize: true);
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(
      routeReplanningControllerProvider.notifier,
    );
    final proposal = _taskReorderProposal(container);
    await controller.registerProposal(proposal);

    final accepting = controller.accept(
      container.read(questControllerProvider).single,
      container.read(missionControllerProvider),
      proposal,
      {proposal.items.single.id},
    );
    await repository.finalizeRequested.future;

    expect(container.read(taskControllerProvider).single.orderIndex, 0);
    expect(
      (await repository.findByQuest(proposal.questId)).single.status,
      RouteProposalStatus.pending,
    );

    repository.releaseFinalize();
    final result = await accepting;
    expect(result?.status, RouteProposalStatus.accepted);
    expect(
      (await repository.findByQuest(proposal.questId)).single.status,
      RouteProposalStatus.accepted,
    );
  });

  test('finalization failure restores the full local snapshot', () async {
    final repository = _RecordingRepository(failFinalize: true);
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(
      routeReplanningControllerProvider.notifier,
    );
    final proposal = _questAndTaskProposal(container);
    await controller.registerProposal(proposal);

    final result = await controller.accept(
      container.read(questControllerProvider).single,
      container.read(missionControllerProvider),
      proposal,
      proposal.items.map((item) => item.id).toSet(),
    );

    expect(result?.status, RouteProposalStatus.stale);
    expect(result?.staleReason, contains('承認前の内容へ戻しました'));
    expect(
      container.read(questControllerProvider).single.targetDate,
      DateTime(2027, 3, 1),
    );
    expect(container.read(taskControllerProvider).single.orderIndex, 1);
    expect(
      (await repository.findByQuest(proposal.questId)).single.status,
      RouteProposalStatus.stale,
    );
  });

  test('recovery failure preserves a manual recovery warning', () async {
    _TaskFixtureController.failRestore = true;
    final repository = _RecordingRepository(failFinalize: true);
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(
      routeReplanningControllerProvider.notifier,
    );
    final proposal = _taskReorderProposal(container);
    await controller.registerProposal(proposal);

    final result = await controller.accept(
      container.read(questControllerProvider).single,
      container.read(missionControllerProvider),
      proposal,
      {proposal.items.single.id},
    );

    expect(result?.status, RouteProposalStatus.stale);
    expect(result?.staleReason, contains('復旧を完了できませんでした'));
    expect(container.read(taskControllerProvider).single.orderIndex, 0);
    expect(
      container
          .read(routeReplanningControllerProvider)[proposal.questId]
          ?.status,
      RouteProposalStatus.stale,
    );
  });

  test('a stale proposal is not applied again', () async {
    final repository = _RecordingRepository(failFinalize: true);
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(
      routeReplanningControllerProvider.notifier,
    );
    final proposal = _taskReorderProposal(container);
    await controller.registerProposal(proposal);
    final selection = {proposal.items.single.id};

    final failed = await controller.accept(
      container.read(questControllerProvider).single,
      container.read(missionControllerProvider),
      proposal,
      selection,
    );
    final callsAfterFailure = repository.applyCalls;
    final replay = await controller.accept(
      container.read(questControllerProvider).single,
      container.read(missionControllerProvider),
      proposal,
      selection,
    );

    expect(failed?.status, RouteProposalStatus.stale);
    expect(replay?.status, RouteProposalStatus.stale);
    expect(repository.applyCalls, callsAfterFailure);
    expect(container.read(taskControllerProvider).single.orderIndex, 1);
  });
}

ProviderContainer _container(RouteReplanningRepository repository) =>
    ProviderContainer(
      overrides: [
        questControllerProvider.overrideWith(_QuestFixtureController.new),
        missionControllerProvider.overrideWith(_MissionFixtureController.new),
        taskControllerProvider.overrideWith(_TaskFixtureController.new),
        routeReplanningRepositoryProvider.overrideWithValue(repository),
      ],
    );

RouteChangeProposal _taskReorderProposal(ProviderContainer container) {
  final task = container.read(taskControllerProvider).single;
  return _proposal(container, [
    RouteChangeItem(
      action: RouteChangeAction.reorder,
      title: 'Taskを先頭にする',
      reason: '次の一歩を明確にする',
      beforeData: const {'orderIndex': 1},
      afterData: const {'orderIndex': 0},
      targetMissionId: task.missionId,
      targetTaskId: task.id,
      safetyLevel: 1,
    ),
  ]);
}

RouteChangeProposal _questAndTaskProposal(ProviderContainer container) {
  final task = container.read(taskControllerProvider).single;
  return _proposal(container, [
    RouteChangeItem(
      action: RouteChangeAction.reschedule,
      title: 'Quest期限を見直す',
      reason: '現実的な航路にする',
      beforeData: const {'targetDate': '2027-03-01'},
      afterData: const {'targetDate': '2027-06-01'},
    ),
    RouteChangeItem(
      action: RouteChangeAction.reorder,
      title: 'Taskを先頭にする',
      reason: '次の一歩を明確にする',
      beforeData: const {'orderIndex': 1},
      afterData: const {'orderIndex': 0},
      targetMissionId: task.missionId,
      targetTaskId: task.id,
      safetyLevel: 1,
    ),
  ]);
}

RouteChangeProposal _proposal(
  ProviderContainer container,
  List<RouteChangeItem> items,
) {
  final quest = container.read(questControllerProvider).single;
  return RouteChangeProposal(
    questId: quest.id,
    reason: RouteProposalReason.manualReview,
    summary: '航路を見直す',
    confidence: 0.9,
    items: items,
    routeSnapshot: const RouteSnapshotService().capture(
      quest: quest,
      missions: container.read(missionControllerProvider),
      tasks: container.read(taskControllerProvider),
    ),
  );
}

class _RecordingRepository extends InMemoryRouteReplanningRepository {
  _RecordingRepository({this.blockFinalize = false, this.failFinalize = false});

  final bool blockFinalize;
  final bool failFinalize;
  final finalizeRequested = Completer<void>();
  final _release = Completer<void>();
  int applyCalls = 0;

  @override
  Future<RouteMutationResult> applyProposal({
    required RouteChangeProposal proposal,
    required List<String> acceptedItemIds,
  }) async {
    applyCalls++;
    if (!finalizeRequested.isCompleted) finalizeRequested.complete();
    if (blockFinalize) await _release.future;
    if (failFinalize) throw StateError('local finalization failed');
    return super.applyProposal(
      proposal: proposal,
      acceptedItemIds: acceptedItemIds,
    );
  }

  void releaseFinalize() {
    if (!_release.isCompleted) _release.complete();
  }
}

class _QuestFixtureController extends QuestController {
  @override
  List<Quest> build() => [
    Quest(
      id: 'quest-a',
      title: '旅に出る',
      description: '旅を実現する',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
      targetDate: DateTime(2027, 3, 1),
    ),
  ];

  @override
  void update(Quest updatedQuest) => state = [updatedQuest];

  @override
  void stageRouteUpdate(Quest updatedQuest) => state = [updatedQuest];

  @override
  Future<bool> persistRouteUpdate(Quest updatedQuest) async => true;

  @override
  Future<bool> restoreRouteSnapshot(Quest quest) async {
    state = [quest];
    return true;
  }
}

class _MissionFixtureController extends MissionController {
  @override
  List<Mission> build() => [
    Mission(
      id: 'mission-a',
      questId: 'quest-a',
      questTitle: '旅に出る',
      title: '旅程を決める',
      description: '日程を決める',
      guideType: GuideType.route,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.todo,
    ),
  ];

  @override
  Future<bool> persistRouteChanges(
    String questId,
    List<Mission> before,
  ) async => true;

  @override
  Future<bool> restoreRouteSnapshot(
    String questId,
    List<Mission> snapshot,
  ) async {
    state = List<Mission>.of(snapshot);
    return true;
  }
}

class _TaskFixtureController extends TaskController {
  static bool failRestore = false;

  @override
  List<QuestraTask> build() => [_task()];

  @override
  Future<bool> updateTask(QuestraTask task) async {
    state = [task];
    return true;
  }

  @override
  Future<void> restoreRouteSnapshot(
    String questId,
    List<QuestraTask> snapshot,
  ) async {
    if (failRestore) throw StateError('restore failed');
    state = List<QuestraTask>.of(snapshot);
  }
}

QuestraTask _task() => QuestraTask(
  id: 'task-a',
  questId: 'quest-a',
  missionId: 'mission-a',
  title: '旅程を確認する',
  action: '希望日を確認する',
  doneCondition: '希望日が決まっている',
  orderIndex: 1,
);
