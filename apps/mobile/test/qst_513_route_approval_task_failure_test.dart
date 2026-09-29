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
  setUp(() => _TaskFixtureController.fail = false);

  test(
    'failed Task update keeps proposal and never reports approval',
    () async {
      _TaskFixtureController.fail = true;
      final repository = InMemoryRouteReplanningRepository();
      final container = _container(repository);
      addTearDown(container.dispose);
      final controller = container.read(
        routeReplanningControllerProvider.notifier,
      );
      final quest = container.read(questControllerProvider).single;
      final missions = container.read(missionControllerProvider);
      final task = container.read(taskControllerProvider).single;
      final proposal = _proposal(container, [
        RouteChangeItem(
          action: RouteChangeAction.reorder,
          title: 'Taskを先頭にする',
          reason: '次の一歩を明確にする',
          beforeData: const {'orderIndex': 1},
          afterData: const {'orderIndex': 0},
          targetTaskId: task.id,
          targetMissionId: task.missionId,
          safetyLevel: 1,
        ),
      ]);
      await controller.registerProposal(proposal);

      final result = await controller.accept(quest, missions, proposal, {
        proposal.items.single.id,
      });

      expect(result?.status, RouteProposalStatus.stale);
      expect(result?.staleReason, contains('承認前の内容へ戻しました'));
      expect(container.read(taskControllerProvider).single.orderIndex, 1);
      expect(
        container.read(routeReplanningControllerProvider)[quest.id]?.status,
        RouteProposalStatus.stale,
      );
      expect(
        (await repository.findByQuest(quest.id)).single.status,
        RouteProposalStatus.stale,
      );
    },
  );

  test(
    'partial local apply is restored and cannot replay the old proposal',
    () async {
      _TaskFixtureController.fail = true;
      final repository = InMemoryRouteReplanningRepository();
      final container = _container(repository);
      addTearDown(container.dispose);
      final controller = container.read(
        routeReplanningControllerProvider.notifier,
      );
      final quest = container.read(questControllerProvider).single;
      final missions = container.read(missionControllerProvider);
      final task = container.read(taskControllerProvider).single;
      final proposal = _proposal(container, [
        RouteChangeItem(
          action: RouteChangeAction.reschedule,
          title: 'Questの期限を変更',
          reason: '航路の見直し',
          beforeData: const {},
          afterData: const {'targetDate': '2027-06-01'},
        ),
        RouteChangeItem(
          action: RouteChangeAction.reschedule,
          title: 'Taskの日程を変更',
          reason: '航路の見直し',
          beforeData: const {},
          afterData: const {'scheduledDate': '2027-05-01'},
          targetTaskId: task.id,
          targetMissionId: task.missionId,
        ),
      ]);
      await controller.registerProposal(proposal);
      final selected = proposal.items.map((item) => item.id).toSet();

      final result = await controller.accept(
        quest,
        missions,
        proposal,
        selected,
      );

      expect(result?.status, RouteProposalStatus.stale);
      expect(result?.staleReason, contains('承認前の内容へ戻しました'));
      expect(
        container.read(questControllerProvider).single.targetDate,
        DateTime(2027, 3, 1),
      );
      expect(
        container.read(taskControllerProvider).single.scheduledDate,
        isNull,
      );
      expect(
        (await repository.findByQuest(quest.id)).single.status,
        RouteProposalStatus.stale,
      );

      final replay = await controller.accept(
        quest,
        missions,
        proposal,
        selected,
      );
      expect(replay?.status, RouteProposalStatus.stale);
      expect(replay?.staleReason, contains('承認前の内容へ戻しました'));
      expect(
        container.read(taskControllerProvider).single.scheduledDate,
        isNull,
      );
    },
  );

  test('successful Task update still approves the proposal', () async {
    final repository = InMemoryRouteReplanningRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(
      routeReplanningControllerProvider.notifier,
    );
    final quest = container.read(questControllerProvider).single;
    final missions = container.read(missionControllerProvider);
    final task = container.read(taskControllerProvider).single;
    final proposal = _proposal(container, [
      RouteChangeItem(
        action: RouteChangeAction.reorder,
        title: 'Taskを先頭にする',
        reason: '次の一歩を明確にする',
        beforeData: const {'orderIndex': 1},
        afterData: const {'orderIndex': 0},
        targetTaskId: task.id,
        targetMissionId: task.missionId,
        safetyLevel: 1,
      ),
    ]);
    await controller.registerProposal(proposal);

    final result = await controller.accept(quest, missions, proposal, {
      proposal.items.single.id,
    });

    expect(result?.status, RouteProposalStatus.accepted);
    expect(container.read(taskControllerProvider).single.orderIndex, 0);
    expect(container.read(routeReplanningControllerProvider)[quest.id], isNull);
    expect(
      (await repository.findByQuest(quest.id)).single.status,
      RouteProposalStatus.accepted,
    );
  });
}

ProviderContainer _container(InMemoryRouteReplanningRepository repository) =>
    ProviderContainer(
      overrides: [
        questControllerProvider.overrideWith(_QuestFixtureController.new),
        missionControllerProvider.overrideWith(_MissionFixtureController.new),
        taskControllerProvider.overrideWith(_TaskFixtureController.new),
        routeReplanningRepositoryProvider.overrideWithValue(repository),
      ],
    );

RouteChangeProposal _proposal(
  ProviderContainer container,
  List<RouteChangeItem> items,
) {
  final quest = container.read(questControllerProvider).single;
  return RouteChangeProposal(
    questId: quest.id,
    reason: RouteProposalReason.manualReview,
    summary: '航路を見直す',
    confidence: 0.8,
    items: items,
    routeSnapshot: const RouteSnapshotService().capture(
      quest: quest,
      missions: container.read(missionControllerProvider),
      tasks: container.read(taskControllerProvider),
    ),
  );
}

class _QuestFixtureController extends QuestController {
  @override
  List<Quest> build() => [
    Quest(
      id: 'quest-a',
      title: '旅に出る',
      description: '次の旅行を実現する',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
      targetDate: DateTime(2027, 3, 1),
    ),
  ];

  @override
  void update(Quest updatedQuest) {
    state = [updatedQuest];
  }

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
      description: '目的地と日程を決める',
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
  static bool fail = false;

  @override
  List<QuestraTask> build() => [
    QuestraTask(
      id: 'task-a',
      questId: 'quest-a',
      missionId: 'mission-a',
      title: '旅程を確認する',
      action: '希望日を確認する',
      doneCondition: '希望日が決まっている',
      orderIndex: 1,
    ),
  ];

  @override
  Future<bool> updateTask(QuestraTask task) async {
    if (fail) return false;
    state = [task];
    return true;
  }

  @override
  Future<bool> reschedule(String taskId, DateTime date) async {
    if (fail) return false;
    state = [state.single.copyWith(scheduledDate: date)];
    return true;
  }
}
