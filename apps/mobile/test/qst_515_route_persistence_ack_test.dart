import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:questra/features/quest/route_replanning_controller.dart';
import 'package:questra/features/quest/route_replanning_model.dart';
import 'package:questra/features/quest/route_replanning_repository.dart';
import 'package:questra/features/quest/route_snapshot_service.dart';
import 'package:questra/features/task/task_controller.dart';
import 'package:questra/features/task/task_model.dart';

void main() {
  test(
    'Quest persistence is acknowledged before proposal finalization',
    () async {
      final questRepository = _DelayedQuestRepository();
      final routeRepository = _RecordingRouteRepository();
      final container = _container(
        questRepository: questRepository,
        missionRepository: InMemoryMissionRepository(),
        routeRepository: routeRepository,
      );
      addTearDown(container.dispose);
      final controller = container.read(
        routeReplanningControllerProvider.notifier,
      );
      final proposal = _questProposal(container);
      await controller.registerProposal(proposal);

      final accepting = controller.accept(
        container.read(questControllerProvider).single,
        container.read(missionControllerProvider),
        proposal,
        {proposal.items.single.id},
      );
      await questRepository.saveRequested.future;

      expect(routeRepository.applyCalls, 0);
      expect(
        (await routeRepository.findByQuest(proposal.questId)).single.status,
        RouteProposalStatus.pending,
      );

      questRepository.release();
      final result = await accepting;
      expect(result?.status, RouteProposalStatus.accepted);
      expect(routeRepository.applyCalls, 1);
    },
  );

  test('Quest persistence failure is restored before approval', () async {
    final questRepository = _FailOnceQuestRepository();
    final routeRepository = _RecordingRouteRepository();
    final container = _container(
      questRepository: questRepository,
      missionRepository: InMemoryMissionRepository(),
      routeRepository: routeRepository,
    );
    addTearDown(container.dispose);
    final controller = container.read(
      routeReplanningControllerProvider.notifier,
    );
    final proposal = _questProposal(container);
    await controller.registerProposal(proposal);

    final result = await controller.accept(
      container.read(questControllerProvider).single,
      container.read(missionControllerProvider),
      proposal,
      {proposal.items.single.id},
    );

    expect(result?.status, RouteProposalStatus.stale);
    expect(result?.staleReason, contains('承認前の内容へ戻しました'));
    expect(routeRepository.applyCalls, 0);
    expect(
      container.read(questControllerProvider).single.targetDate,
      DateTime(2027, 3, 1),
    );
    expect(questRepository.saveCalls, 2);
  });

  test('Mission persistence failure is restored before approval', () async {
    final missionRepository = _FailOnceMissionRepository();
    final routeRepository = _RecordingRouteRepository();
    final container = _container(
      questRepository: InMemoryQuestRepository(),
      missionRepository: missionRepository,
      routeRepository: routeRepository,
    );
    addTearDown(container.dispose);
    final controller = container.read(
      routeReplanningControllerProvider.notifier,
    );
    final proposal = _missionProposal(container);
    await controller.registerProposal(proposal);

    final result = await controller.accept(
      container.read(questControllerProvider).single,
      container.read(missionControllerProvider),
      proposal,
      {proposal.items.single.id},
    );

    expect(result?.status, RouteProposalStatus.stale);
    expect(result?.staleReason, contains('承認前の内容へ戻しました'));
    expect(routeRepository.applyCalls, 0);
    expect(container.read(missionControllerProvider).single.title, '旅程を決める');
    expect(missionRepository.saveCalls, 2);
  });
}

ProviderContainer _container({
  required QuestRepository questRepository,
  required MissionRepository missionRepository,
  required RouteReplanningRepository routeRepository,
}) => ProviderContainer(
  overrides: [
    authControllerProvider.overrideWith(_AuthFixture.new),
    questControllerProvider.overrideWith(_QuestFixtureController.new),
    missionControllerProvider.overrideWith(_MissionFixtureController.new),
    taskControllerProvider.overrideWith(_TaskFixtureController.new),
    questRepositoryProvider.overrideWithValue(questRepository),
    missionRepositoryProvider.overrideWithValue(missionRepository),
    routeReplanningRepositoryProvider.overrideWithValue(routeRepository),
  ],
);

RouteChangeProposal _questProposal(ProviderContainer container) =>
    _proposal(container, [
      RouteChangeItem(
        action: RouteChangeAction.reschedule,
        title: 'Quest期限を見直す',
        reason: '現実的な航路にする',
        beforeData: const {'targetDate': '2027-03-01'},
        afterData: const {'targetDate': '2027-06-01'},
      ),
    ]);

RouteChangeProposal _missionProposal(ProviderContainer container) =>
    _proposal(container, [
      RouteChangeItem(
        action: RouteChangeAction.replace,
        title: 'Missionを具体化する',
        reason: '完了条件を明確にする',
        beforeData: const {'title': '旅程を決める'},
        afterData: const {'title': '同行者と旅行日程を決める'},
        targetMissionId: 'mission-a',
        safetyLevel: 3,
      ),
    ]);

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

class _AuthFixture extends AuthController {
  @override
  AuthState build() => const AuthState(
    profile: UserProfile(
      id: 'owner-a',
      email: 'owner-a@example.invalid',
      nickname: 'A',
    ),
  );
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
}

class _TaskFixtureController extends TaskController {
  @override
  List<QuestraTask> build() => const [];

  @override
  Future<void> restoreRouteSnapshot(
    String questId,
    List<QuestraTask> snapshot,
  ) async {}
}

class _RecordingRouteRepository extends InMemoryRouteReplanningRepository {
  int applyCalls = 0;

  @override
  Future<RouteMutationResult> applyProposal({
    required RouteChangeProposal proposal,
    required List<String> acceptedItemIds,
  }) {
    applyCalls++;
    return super.applyProposal(
      proposal: proposal,
      acceptedItemIds: acceptedItemIds,
    );
  }
}

class _DelayedQuestRepository extends InMemoryQuestRepository {
  final saveRequested = Completer<void>();
  final _release = Completer<void>();

  @override
  Future<Quest> save({required String ownerId, required Quest quest}) async {
    if (!saveRequested.isCompleted) saveRequested.complete();
    await _release.future;
    return super.save(ownerId: ownerId, quest: quest);
  }

  void release() => _release.complete();
}

class _FailOnceQuestRepository extends InMemoryQuestRepository {
  int saveCalls = 0;

  @override
  Future<Quest> save({required String ownerId, required Quest quest}) async {
    saveCalls++;
    if (saveCalls == 1) throw StateError('quest save failed');
    return super.save(ownerId: ownerId, quest: quest);
  }
}

class _FailOnceMissionRepository extends InMemoryMissionRepository {
  int saveCalls = 0;

  @override
  Future<Mission> save(Mission mission) async {
    saveCalls++;
    if (saveCalls == 1) throw StateError('mission save failed');
    return super.save(mission);
  }
}
