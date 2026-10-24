import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/quest/quest_route_screen.dart';
import 'package:questra/features/quest/route_mutation_journal.dart';
import 'package:questra/features/quest/route_replanning_controller.dart';
import 'package:questra/features/quest/route_replanning_model.dart';
import 'package:questra/features/quest/route_replanning_repository.dart';
import 'package:questra/features/quest/route_snapshot_service.dart';
import 'package:questra/features/task/task_controller.dart';
import 'package:questra/features/task/task_model.dart';

void main() {
  final original = _quest();
  final mission = _mission();
  final task = _task();
  final before = const RouteSnapshotService().capture(
    quest: original,
    missions: [mission],
    tasks: [task],
  );

  ProviderContainer container(InMemoryRouteMutationJournalRepository journal) =>
      ProviderContainer(
        overrides: [
          questControllerProvider.overrideWith(_QuestFixture.new),
          missionControllerProvider.overrideWith(_MissionFixture.new),
          taskControllerProvider.overrideWith(_TaskFixture.new),
          routeMutationJournalRepositoryProvider.overrideWithValue(journal),
          routeReplanningRepositoryProvider.overrideWithValue(
            InMemoryRouteReplanningRepository(),
          ),
        ],
      );

  RouteMutationJournal entry(
    RouteJournalStage stage, {
    Map<String, Object?>? after,
  }) => RouteMutationJournal(
    ownerId: 'local-preview',
    questId: original.id,
    proposalId: 'proposal-1',
    stage: stage,
    beforeSnapshot: before,
    afterSnapshot: after,
    createdAt: DateTime.utc(2026, 9, 30),
  );

  test('restart can reconcile only a matching unfinished route', () async {
    final journal = InMemoryRouteMutationJournalRepository();
    await journal.save(entry(RouteJournalStage.applying));
    final first = container(journal);
    first.read(routeReplanningControllerProvider.notifier);
    first.dispose();

    final restarted = container(journal);
    addTearDown(restarted.dispose);
    final controller = restarted.read(
      routeReplanningControllerProvider.notifier,
    );
    final inspection = await controller.inspectRouteJournal(
      restarted.read(questControllerProvider).single,
      restarted.read(missionControllerProvider),
    );
    expect(inspection?.disposition, RouteJournalDisposition.notApplied);
    expect(inspection?.canAcknowledge, isTrue);
    expect(await journal.load('local-preview', original.id), isNotNull);
    expect(
      await controller.acknowledgeRouteJournal(original.id, 'proposal-1'),
      isTrue,
    );
    expect(await journal.load('local-preview', original.id), isNull);
    expect(
      restarted.read(questControllerProvider).single.targetDate,
      original.targetDate,
    );
  });

  test('journal acknowledgment is single-flight for the same Quest', () async {
    final journal = _PausedJournalRepository();
    await journal.save(entry(RouteJournalStage.applying));
    final restarted = container(journal);
    addTearDown(restarted.dispose);
    final controller = restarted.read(
      routeReplanningControllerProvider.notifier,
    );

    journal.pauseNextLoad = true;
    final first = controller.acknowledgeRouteJournal(original.id, 'proposal-1');
    await journal.loadStarted.future;
    expect(
      await controller.acknowledgeRouteJournal(original.id, 'proposal-1'),
      isFalse,
    );
    journal.resumeLoad.complete();
    expect(await first, isTrue);
    expect(await journal.load('local-preview', original.id), isNull);
  });

  test(
    'later route change keeps the journal and rejects a new approval',
    () async {
      final journal = InMemoryRouteMutationJournalRepository();
      await journal.save(entry(RouteJournalStage.applying));
      final restarted = container(journal);
      addTearDown(restarted.dispose);
      final changed = original.copyWith(targetDate: DateTime(2027, 6, 1));
      restarted.read(questControllerProvider.notifier).update(changed);
      final controller = restarted.read(
        routeReplanningControllerProvider.notifier,
      );
      final inspection = await controller.inspectRouteJournal(
        changed,
        restarted.read(missionControllerProvider),
      );
      expect(inspection?.disposition, RouteJournalDisposition.unknown);
      expect(inspection?.canAcknowledge, isFalse);
      expect(
        await controller.acknowledgeRouteJournal(original.id, 'proposal-1'),
        isFalse,
      );
      expect(await journal.load('local-preview', original.id), isNotNull);

      final proposal = RouteChangeProposal(
        questId: original.id,
        reason: RouteProposalReason.manualReview,
        summary: '別の航路変更',
        confidence: 0.9,
        routeSnapshot: const RouteSnapshotService().capture(
          quest: changed,
          missions: restarted.read(missionControllerProvider),
          tasks: restarted.read(taskControllerProvider),
        ),
        items: [
          RouteChangeItem(
            action: RouteChangeAction.reschedule,
            title: '期限を見直す',
            reason: '進捗に合わせる',
            beforeData: const {'targetDate': '2027-06-01'},
            afterData: const {'targetDate': '2027-07-01'},
          ),
        ],
      );
      await expectLater(
        controller.accept(
          changed,
          restarted.read(missionControllerProvider),
          proposal,
          {proposal.items.single.id},
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        restarted.read(questControllerProvider).single.targetDate,
        changed.targetDate,
      );
    },
  );

  test(
    'recovery-needed journal can be acknowledged only after before-state match',
    () async {
      final journal = InMemoryRouteMutationJournalRepository();
      await journal.save(
        entry(RouteJournalStage.recoveryNeeded, after: before),
      );
      final restarted = container(journal);
      addTearDown(restarted.dispose);
      final controller = restarted.read(
        routeReplanningControllerProvider.notifier,
      );
      final inspection = await controller.inspectRouteJournal(
        original,
        restarted.read(missionControllerProvider),
      );
      expect(inspection?.disposition, RouteJournalDisposition.recoveryNeeded);
      expect(inspection?.matchesBefore, isTrue);
      expect(inspection?.canAcknowledge, isTrue);
      expect(
        await controller.acknowledgeRouteJournal(original.id, 'proposal-1'),
        isTrue,
      );
      expect(await journal.load('local-preview', original.id), isNull);
    },
  );

  test(
    'partial recovery cannot be acknowledged after another change',
    () async {
      final journal = InMemoryRouteMutationJournalRepository();
      await journal.save(
        entry(RouteJournalStage.recoveryNeeded, after: before),
      );
      final restarted = container(journal);
      addTearDown(restarted.dispose);
      final changed = original.copyWith(targetDate: DateTime(2027, 6, 1));
      restarted.read(questControllerProvider.notifier).update(changed);
      final controller = restarted.read(
        routeReplanningControllerProvider.notifier,
      );
      final inspection = await controller.inspectRouteJournal(
        changed,
        restarted.read(missionControllerProvider),
      );
      expect(inspection?.matchesBefore, isFalse);
      expect(inspection?.matchesAfter, isFalse);
      expect(inspection?.canAcknowledge, isFalse);
      expect(
        await controller.acknowledgeRouteJournal(original.id, 'proposal-1'),
        isFalse,
      );
      expect(await journal.load('local-preview', original.id), isNotNull);
    },
  );

  test(
    'interrupted Undo can be acknowledged only at its restore target',
    () async {
      final journal = InMemoryRouteMutationJournalRepository();
      final applied = original.copyWith(targetDate: DateTime(2027, 6, 1));
      final appliedSnapshot = const RouteSnapshotService().capture(
        quest: applied,
        missions: [mission],
        tasks: [task],
      );
      await journal.save(
        RouteMutationJournal(
          ownerId: 'local-preview',
          questId: original.id,
          proposalId: 'proposal-undo',
          stage: RouteJournalStage.recovering,
          beforeSnapshot: appliedSnapshot,
          afterSnapshot: before,
          createdAt: DateTime.utc(2026, 9, 30),
        ),
      );
      final restarted = container(journal);
      addTearDown(restarted.dispose);
      final controller = restarted.read(
        routeReplanningControllerProvider.notifier,
      );
      final inspection = await controller.inspectRouteJournal(
        original,
        restarted.read(missionControllerProvider),
      );
      expect(inspection?.matchesAfter, isTrue);
      expect(inspection?.canAcknowledge, isTrue);
      expect(
        await controller.acknowledgeRouteJournal(original.id, 'proposal-undo'),
        isTrue,
      );
      expect(await journal.load('local-preview', original.id), isNull);
    },
  );

  testWidgets('route screen blocks review until explicit reconciliation', (
    tester,
  ) async {
    final journal = InMemoryRouteMutationJournalRepository();
    await journal.save(entry(RouteJournalStage.applying));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questControllerProvider.overrideWith(_QuestFixture.new),
          missionControllerProvider.overrideWith(_MissionFixture.new),
          taskControllerProvider.overrideWith(_TaskFixture.new),
          routeMutationJournalRepositoryProvider.overrideWithValue(journal),
          routeReplanningRepositoryProvider.overrideWithValue(
            InMemoryRouteReplanningRepository(),
          ),
        ],
        child: const MaterialApp(home: QuestRouteScreen(questId: 'quest-a')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('現在の航路は変更前と一致します'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Arcと航路を見直す'),
          )
          .onPressed,
      isNull,
    );

    await tester.ensureVisible(find.text('照合結果を確認して続ける'));
    await tester.tap(find.text('照合結果を確認して続ける'));
    await tester.pumpAndSettle();
    expect(await journal.load('local-preview', original.id), isNotNull);
    await tester.tap(find.text('戻る'));
    await tester.pumpAndSettle();
    expect(await journal.load('local-preview', original.id), isNotNull);
    await tester.tap(find.text('照合結果を確認して続ける'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('確認して続ける'));
    await tester.pumpAndSettle();
    expect(await journal.load('local-preview', original.id), isNull);
    expect(find.text('現在の航路を確認しました。'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Arcと航路を見直す'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('corrupt journal blocks review without clearing evidence', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questControllerProvider.overrideWith(_QuestFixture.new),
          missionControllerProvider.overrideWith(_MissionFixture.new),
          taskControllerProvider.overrideWith(_TaskFixture.new),
          routeMutationJournalRepositoryProvider.overrideWithValue(
            _CorruptJournalRepository(),
          ),
        ],
        child: const MaterialApp(home: QuestRouteScreen(questId: 'quest-a')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('復旧記録を確認できません'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Arcと航路を見直す'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('照合結果を確認して続ける'), findsNothing);
  });
}

Quest _quest() => Quest(
  id: 'quest-a',
  title: '旅に出る',
  description: '新しい場所を訪ねる',
  difficulty: QuestDifficulty.normal,
  status: QuestStatus.active,
  visibility: QuestVisibility.private,
  targetDate: DateTime(2027, 3, 1),
);

Mission _mission() => Mission(
  id: 'mission-a',
  questId: 'quest-a',
  questTitle: '旅に出る',
  title: '旅程を決める',
  description: '希望の日程を決める',
  guideType: GuideType.route,
  difficulty: MissionDifficulty.easy,
  status: MissionStatus.todo,
);

QuestraTask _task() => QuestraTask(
  id: 'task-a',
  questId: 'quest-a',
  missionId: 'mission-a',
  title: '候補日を調べる',
  action: '候補日を確認する',
  doneCondition: '候補日が決まっている',
);

class _QuestFixture extends QuestController {
  @override
  List<Quest> build() => [_quest()];

  @override
  void update(Quest updatedQuest) => state = [updatedQuest];
}

class _MissionFixture extends MissionController {
  @override
  List<Mission> build() => [_mission()];
}

class _TaskFixture extends TaskController {
  @override
  List<QuestraTask> build() => [_task()];
}

class _CorruptJournalRepository extends InMemoryRouteMutationJournalRepository {
  @override
  Future<RouteMutationJournal?> load(String ownerId, String questId) async =>
      throw const RouteJournalIntegrityException();
}

class _PausedJournalRepository extends InMemoryRouteMutationJournalRepository {
  final loadStarted = Completer<void>();
  final resumeLoad = Completer<void>();
  bool pauseNextLoad = false;

  @override
  Future<RouteMutationJournal?> load(String ownerId, String questId) async {
    if (pauseNextLoad) {
      pauseNextLoad = false;
      loadStarted.complete();
      await resumeLoad.future;
    }
    return super.load(ownerId, questId);
  }
}
