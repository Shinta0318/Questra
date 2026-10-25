import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/analytics/analytics_event.dart';
import '../../core/analytics/analytics_service.dart';
import '../mission/mission_controller.dart';
import '../mission/mission_model.dart';
import '../task/task_controller.dart';
import '../task/task_model.dart';
import '../auth/auth_controller.dart';
import 'adaptive_route_service.dart';
import 'quest_controller.dart';
import 'quest_guide_model.dart';
import 'quest_model.dart';
import 'route_replanning_model.dart';
import 'route_replanning_repository.dart';
import 'route_snapshot_service.dart';
import 'route_replanning_trigger_service.dart';
import 'route_mutation_journal.dart';

final routeReplanningControllerProvider =
    NotifierProvider<
      RouteReplanningController,
      Map<String, RouteChangeProposal>
    >(RouteReplanningController.new);

class RouteReplanningController
    extends Notifier<Map<String, RouteChangeProposal>> {
  final Map<String, List<Mission>> _undoMissions = {};
  final Map<String, Quest> _undoQuests = {};
  final Map<String, RouteChangeProposal> _undoProposals = {};
  final Map<String, List<QuestraTask>> _undoTasks = {};
  final Map<String, Map<String, Object?>> _undoAppliedSnapshots = {};
  final Map<String, Map<String, Object?>> _undoRecoverySnapshots = {};
  final Map<String, String?> _undoOwners = {};
  final Set<String> _undoInProgress = {};
  final Set<String> _acceptInProgress = {};
  final Set<String> _acknowledgmentInProgress = {};
  final Set<String> _remoteRolledBack = {};
  final Map<String, DateTime> _lastEvaluatedAt = {};

  String? undoProposalIdForQuest(String questId) {
    for (final proposal in _undoProposals.values.toList().reversed) {
      if (proposal.questId == questId) return proposal.id;
    }
    return null;
  }

  bool hasFailedAcceptanceRecovery(String proposalId) =>
      _undoQuests.containsKey(proposalId) &&
      _undoMissions.containsKey(proposalId) &&
      _undoTasks.containsKey(proposalId);

  String _operationKey(String questId) =>
      '${ref.read(authControllerProvider).profile?.id ?? 'local-preview'}:$questId';

  bool _undoBusyForQuest(String questId) => _undoInProgress.any(
    (proposalId) =>
        _undoProposals[proposalId]?.questId == questId ||
        _undoQuests[proposalId]?.id == questId,
  );

  @override
  Map<String, RouteChangeProposal> build() {
    ref.listen(missionControllerProvider, (previous, next) {
      if (previous == null) return;
      for (final mission in next) {
        final before = previous
            .where((item) => item.id == mission.id)
            .firstOrNull;
        if (before?.status != MissionStatus.completed &&
            mission.status == MissionStatus.completed) {
          final quest = ref
              .read(questControllerProvider)
              .where((item) => item.id == mission.questId)
              .firstOrNull;
          if (quest != null) {
            unawaited(
              _reviewWithTrigger(
                quest,
                next.where((item) => item.questId == quest.id).toList(),
                RouteReplanningTrigger.missionCompleted,
                eventId: 'completed:${mission.id}',
              ),
            );
          }
        }
      }
    });
    ref.listen(missionControllerProvider, (previous, next) {
      if (next.isEmpty) return;
      final quests = ref.read(questControllerProvider);
      for (final quest in quests) {
        final pending = next
            .where(
              (mission) =>
                  mission.questId == quest.id &&
                  mission.status == MissionStatus.todo &&
                  mission.routeState == MissionRouteState.active,
            )
            .toList(growable: false);
        if (pending.isEmpty) continue;
        final oldest = pending.reduce(
          (a, b) => a.updatedAt.isBefore(b.updatedAt) ? a : b,
        );
        if (DateTime.now().difference(oldest.updatedAt).inDays >= 7) {
          unawaited(
            reviewForTrigger(
              quest,
              pending,
              RouteReplanningTrigger.inactive,
              eventId: 'inactive:${oldest.id}',
            ),
          );
        }
      }
    });
    ref.listen(questControllerProvider, (previous, next) {
      for (final quest in next) {
        final targetDate = quest.targetDate;
        if (quest.status == QuestStatus.active &&
            targetDate != null &&
            targetDate.isBefore(DateTime.now())) {
          unawaited(
            reviewForTrigger(
              quest,
              ref
                  .read(missionControllerProvider)
                  .where((mission) => mission.questId == quest.id)
                  .toList(growable: false),
              RouteReplanningTrigger.missionDeadlineMissed,
              eventId: 'deadline:${targetDate.toIso8601String()}',
            ),
          );
        }
      }
    });
    return const {};
  }

  Future<RouteChangeProposal?> review(
    Quest quest,
    List<Mission> missions,
  ) async {
    return _reviewWithTrigger(quest, missions, RouteReplanningTrigger.manual);
  }

  Future<RouteChangeProposal?> reviewForTrigger(
    Quest quest,
    List<Mission> missions,
    RouteReplanningTrigger trigger, {
    String? eventId,
  }) {
    return _reviewWithTrigger(quest, missions, trigger, eventId: eventId);
  }

  Future<RouteChangeProposal> registerProposal(
    RouteChangeProposal proposal,
  ) async {
    final validated = const RouteProposalValidator().validate(proposal);
    await ref.read(routeReplanningRepositoryProvider).saveProposal(validated);
    state = {...state, validated.questId: validated};
    return validated;
  }

  Future<RouteChangeProposal?> _reviewWithTrigger(
    Quest quest,
    List<Mission> missions,
    RouteReplanningTrigger trigger, {
    String? eventId,
  }) async {
    final decision = const RouteReplanningTriggerService().decide(
      questId: quest.id,
      trigger: trigger,
      lastEvaluatedAt: _lastEvaluatedAt[quest.id],
      eventId: eventId,
    );
    if (!decision.shouldEvaluate) return null;
    final proposal = AdaptiveRouteService.buildStructuredProposal(
      quest: quest,
      missions: missions,
      tasks: ref
          .read(taskControllerProvider)
          .where((task) => task.questId == quest.id)
          .toList(growable: false),
    );
    if (proposal == null) return null;
    await ref.read(routeReplanningRepositoryProvider).saveProposal(proposal);
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .progress(
            name: AnalyticsEventName.routeReplanned,
            userId: ref.read(authControllerProvider).profile?.id,
            questId: quest.id,
            routeId: proposal.routeVersionId,
            source: AnalyticsEventSource.arc,
            properties: {
              'reason_code': trigger.name,
              'proposal_type': proposal.items.length == 1
                  ? 'single'
                  : 'multiple',
            },
          ),
    );
    _lastEvaluatedAt[quest.id] = DateTime.now();
    state = {...state, quest.id: proposal};
    return proposal;
  }

  Future<void> reject(RouteChangeProposal proposal) async {
    await ref
        .read(routeReplanningRepositoryProvider)
        .resolveProposal(proposal.id, RouteProposalStatus.rejected);
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .progress(
            name: AnalyticsEventName.routeRejected,
            userId: ref.read(authControllerProvider).profile?.id,
            questId: proposal.questId,
            routeId: proposal.routeVersionId,
          ),
    );
    state = Map.of(state)..remove(proposal.questId);
  }

  Future<RouteMutationResult?> accept(
    Quest quest,
    List<Mission> missions,
    RouteChangeProposal proposal,
    Set<String> acceptedItemIds,
  ) async {
    final operationKey = _operationKey(quest.id);
    if (_acknowledgmentInProgress.contains(operationKey) ||
        _undoBusyForQuest(quest.id) ||
        !_acceptInProgress.add(operationKey)) {
      throw StateError('このQuestの航路を反映中です。完了してから確認してください。');
    }
    try {
      return await _acceptInternal(quest, missions, proposal, acceptedItemIds);
    } finally {
      _acceptInProgress.remove(operationKey);
    }
  }

  Future<RouteMutationResult?> _acceptInternal(
    Quest quest,
    List<Mission> missions,
    RouteChangeProposal proposal,
    Set<String> acceptedItemIds,
  ) async {
    final tracked = state[proposal.questId];
    if (proposal.status != RouteProposalStatus.pending ||
        (tracked?.id == proposal.id &&
            tracked?.status != RouteProposalStatus.pending)) {
      final current = tracked?.id == proposal.id ? tracked! : proposal;
      return RouteMutationResult(
        proposalId: proposal.id,
        questId: proposal.questId,
        routeVersionId: proposal.routeVersionId,
        status: current.status,
        persistedAtomically: false,
        staleReason: current.staleReason,
        conflictSnapshot: current.conflictSnapshot,
      );
    }
    final selected = proposal.items
        .where((item) => acceptedItemIds.contains(item.id))
        .toList(growable: false);
    if (selected.isEmpty) return null;
    final journalOwner =
        ref.read(authControllerProvider).profile?.id ?? 'local-preview';
    if (await ref
            .read(routeMutationJournalRepositoryProvider)
            .load(journalOwner, quest.id) !=
        null) {
      throw StateError('前回の航路操作を確認してから、次の変更を進めてください。');
    }
    final tasks = ref
        .read(taskControllerProvider)
        .where((task) => task.questId == quest.id)
        .toList(growable: false);
    final currentSnapshot = const RouteSnapshotService().capture(
      quest: quest,
      missions: missions,
      tasks: tasks,
    );
    final conflict = const RouteSnapshotService().compare(
      proposal.routeSnapshot,
      currentSnapshot,
    );
    if (conflict.isStale) {
      await ref
          .read(routeReplanningRepositoryProvider)
          .resolveProposal(proposal.id, RouteProposalStatus.stale);
      final stale = proposal.copyWith(
        status: RouteProposalStatus.stale,
        staleReason: conflict.message,
        conflictSnapshot: currentSnapshot,
      );
      state = {...state, proposal.questId: stale};
      return RouteMutationResult(
        proposalId: proposal.id,
        questId: proposal.questId,
        routeVersionId: proposal.routeVersionId,
        status: RouteProposalStatus.stale,
        persistedAtomically: false,
        staleReason: conflict.message,
        conflictSnapshot: currentSnapshot,
      );
    }
    final repository = ref.read(routeReplanningRepositoryProvider);
    late RouteMutationResult result;
    var journalCleanupIncomplete = false;
    if (repository.appliesProposalAtomically) {
      result = await repository.applyProposal(
        proposal: proposal,
        acceptedItemIds: selected.map((item) => item.id).toList(),
      );
      if (result.status == RouteProposalStatus.stale) {
        state = {
          ...state,
          proposal.questId: proposal.copyWith(
            status: RouteProposalStatus.stale,
            staleReason: result.staleReason,
            conflictSnapshot: result.conflictSnapshot,
          ),
        };
        return result;
      }
      await _reloadOwnedRoute();
    } else {
      final journalRepository = ref.read(
        routeMutationJournalRepositoryProvider,
      );
      final journalOwner =
          ref.read(authControllerProvider).profile?.id ?? 'local-preview';
      if (await journalRepository.load(journalOwner, quest.id) != null) {
        throw StateError('前回の航路操作を確認してから、次の変更を進めてください。');
      }
      final journal = RouteMutationJournal(
        ownerId: journalOwner,
        questId: quest.id,
        proposalId: proposal.id,
        stage: RouteJournalStage.applying,
        beforeSnapshot: currentSnapshot,
        createdAt: DateTime.now().toUtc(),
      );
      await journalRepository.save(journal);
      _undoMissions[proposal.id] = List<Mission>.of(missions);
      _undoQuests[proposal.id] = quest;
      _undoTasks[proposal.id] = ref
          .read(taskControllerProvider)
          .where((task) => task.questId == quest.id)
          .toList(growable: false);
      _undoOwners[proposal.id] = ref.read(authControllerProvider).profile?.id;
      try {
        for (final item in selected) {
          await _applyItem(quest, missions, item);
        }
        final stagedQuest =
            ref
                .read(questControllerProvider)
                .where((item) => item.id == quest.id)
                .firstOrNull ??
            quest;
        final stagedSnapshot = const RouteSnapshotService().capture(
          quest: stagedQuest,
          missions: ref.read(missionControllerProvider),
          tasks: ref.read(taskControllerProvider),
        );
        final stagedChanges = const RouteSnapshotService().compare(
          currentSnapshot,
          stagedSnapshot,
        );
        final missionChanged = selected.any(_changesMissionRoute);
        if ((stagedChanges.changedEntityIds.contains('quest') ||
                missionChanged) &&
            !await ref
                .read(questControllerProvider.notifier)
                .persistRouteUpdate(stagedQuest)) {
          throw StateError('Questの航路変更を保存できませんでした。');
        }
        if (missionChanged &&
            !await ref
                .read(missionControllerProvider.notifier)
                .persistRouteChanges(quest.id, missions)) {
          throw StateError('Missionの航路変更を保存できませんでした。');
        }
        result = await repository.applyProposal(
          proposal: proposal,
          acceptedItemIds: selected.map((item) => item.id).toList(),
        );
        if (result.status == RouteProposalStatus.stale) {
          throw StateError('航路変更案が最新の状態と一致しません。');
        }
      } catch (_) {
        final restored = await _restoreLocalSnapshot(
          quest: quest,
          missions: missions,
          tasks: tasks,
        );
        final latestQuest = ref
            .read(questControllerProvider)
            .where((item) => item.id == quest.id)
            .firstOrNull;
        final latestSnapshot = const RouteSnapshotService().capture(
          quest: latestQuest ?? quest,
          missions: ref.read(missionControllerProvider),
          tasks: ref.read(taskControllerProvider),
        );
        final reason = restored
            ? '航路を更新できなかったため、承認前の内容へ戻しました。最新の航路で提案を作り直してください。'
            : '航路の復旧を完了できませんでした。現在の内容を確認し、提案を作り直してください。';
        final stale = proposal.copyWith(
          status: RouteProposalStatus.stale,
          staleReason: reason,
          conflictSnapshot: latestSnapshot,
        );
        state = {...state, proposal.questId: stale};
        if (restored) {
          await journalRepository.clear(journalOwner, quest.id);
          _undoMissions.remove(proposal.id);
          _undoQuests.remove(proposal.id);
          _undoTasks.remove(proposal.id);
          _undoOwners.remove(proposal.id);
        } else {
          await journalRepository.save(
            journal.copyWith(
              stage: RouteJournalStage.recoveryNeeded,
              afterSnapshot: latestSnapshot,
              attempts: 1,
            ),
          );
        }
        await ref
            .read(routeReplanningRepositoryProvider)
            .resolveProposal(proposal.id, RouteProposalStatus.stale);
        return RouteMutationResult(
          proposalId: proposal.id,
          questId: proposal.questId,
          routeVersionId: proposal.routeVersionId,
          status: RouteProposalStatus.stale,
          persistedAtomically: false,
          staleReason: reason,
          conflictSnapshot: latestSnapshot,
          recoveryIncomplete: !restored,
        );
      }
      try {
        await journalRepository.save(
          journal.copyWith(
            stage: RouteJournalStage.applied,
            afterSnapshot: const RouteSnapshotService().capture(
              quest:
                  ref
                      .read(questControllerProvider)
                      .where((item) => item.id == quest.id)
                      .firstOrNull ??
                  quest,
              missions: ref.read(missionControllerProvider),
              tasks: ref.read(taskControllerProvider),
            ),
          ),
        );
        await journalRepository.clear(journalOwner, quest.id);
        if (await journalRepository.load(journalOwner, quest.id) != null) {
          journalCleanupIncomplete = true;
        }
      } catch (_) {
        journalCleanupIncomplete = true;
      }
    }
    _undoProposals[proposal.id] = proposal;
    if (!repository.appliesProposalAtomically) {
      final appliedQuest = ref
          .read(questControllerProvider)
          .where((entry) => entry.id == quest.id)
          .firstOrNull;
      if (appliedQuest != null) {
        _undoAppliedSnapshots[proposal.id] = const RouteSnapshotService()
            .capture(
              quest: appliedQuest,
              missions: ref.read(missionControllerProvider),
              tasks: ref.read(taskControllerProvider),
            );
      }
      _undoOwners[proposal.id] = ref.read(authControllerProvider).profile?.id;
    }
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .progress(
            name: AnalyticsEventName.routeApproved,
            userId: ref.read(authControllerProvider).profile?.id,
            questId: proposal.questId,
            routeId: proposal.routeVersionId,
            properties: {'interaction': 'approved'},
          ),
    );
    state = Map.of(state)..remove(proposal.questId);
    if (journalCleanupIncomplete) {
      return RouteMutationResult(
        proposalId: result.proposalId,
        questId: result.questId,
        routeVersionId: result.routeVersionId,
        status: result.status,
        persistedAtomically: result.persistedAtomically,
        recoveryIncomplete: true,
        staleReason: '航路は更新されましたが、復旧記録を整理できませんでした。現在の航路を確認してください。',
      );
    }
    return result;
  }

  Future<bool> _restoreLocalSnapshot({
    required Quest quest,
    required List<Mission> missions,
    required List<QuestraTask> tasks,
  }) async {
    var questRestored = false;
    var missionsRestored = false;
    var tasksRestored = false;
    try {
      questRestored = await ref
          .read(questControllerProvider.notifier)
          .restoreRouteSnapshot(quest);
    } catch (_) {
      questRestored = false;
    }
    try {
      missionsRestored = await ref
          .read(missionControllerProvider.notifier)
          .restoreRouteSnapshot(quest.id, missions);
    } catch (_) {
      missionsRestored = false;
    }
    try {
      await ref
          .read(taskControllerProvider.notifier)
          .restoreRouteSnapshot(quest.id, tasks);
      tasksRestored = true;
    } catch (_) {
      tasksRestored = false;
    }
    return questRestored && missionsRestored && tasksRestored;
  }

  bool _changesMissionRoute(RouteChangeItem item) {
    if (item.targetTaskId != null || item.targetMissionId == null) {
      return false;
    }
    return switch (item.action) {
      RouteChangeAction.reorder ||
      RouteChangeAction.split ||
      RouteChangeAction.pause ||
      RouteChangeAction.remove ||
      RouteChangeAction.resume ||
      RouteChangeAction.replace => true,
      RouteChangeAction.add ||
      RouteChangeAction.merge ||
      RouteChangeAction.reschedule ||
      RouteChangeAction.reestimate => false,
    };
  }

  Future<RouteChangeProposal?> refreshStale(
    Quest quest,
    List<Mission> missions,
    RouteChangeProposal proposal,
  ) async {
    if (proposal.status != RouteProposalStatus.stale) return proposal;
    state = Map.of(state)..remove(proposal.questId);
    return review(quest, missions);
  }

  Future<void> _applyItem(
    Quest quest,
    List<Mission> missions,
    RouteChangeItem item,
  ) async {
    final missionController = ref.read(missionControllerProvider.notifier);
    final taskController = ref.read(taskControllerProvider.notifier);
    final task = item.targetTaskId == null
        ? null
        : ref
              .read(taskControllerProvider)
              .where((entry) => entry.id == item.targetTaskId)
              .firstOrNull;
    if (item.targetTaskId != null && task == null) {
      throw StateError('変更対象のTaskが見つかりません。');
    }
    if (task?.status == TaskStatus.completed) {
      throw StateError('完了済みTaskは変更できません。');
    }
    switch (item.action) {
      case RouteChangeAction.reschedule:
        if (task != null) {
          final value = item.afterData['scheduledDate'] as String?;
          final date = value == null ? null : DateTime.tryParse(value);
          if (date == null || !await taskController.reschedule(task.id, date)) {
            throw StateError('Taskの日程を変更できませんでした。');
          }
          break;
        }
        final value = item.afterData['targetDate'] as String?;
        if (value != null) {
          ref
              .read(questControllerProvider.notifier)
              .stageRouteUpdate(
                quest.copyWith(targetDate: DateTime.tryParse(value)),
              );
        }
        break;
      case RouteChangeAction.reorder:
        if (task != null) {
          final order = item.afterData['orderIndex'] as int?;
          if (order == null ||
              !await taskController.updateTask(
                task.copyWith(orderIndex: order),
              )) {
            throw StateError('Taskの順番を変更できませんでした。');
          }
          break;
        }
        final missionId = item.targetMissionId;
        if (missionId != null) {
          missionController.setToday(quest.id, missionId, persist: false);
        }
        break;
      case RouteChangeAction.split:
        if (task != null) {
          final values = item.afterData['tasks'] as List?;
          if (values == null || values.isEmpty) {
            throw StateError('Taskの分割内容がありません。');
          }
          if (!await taskController.updateTask(
            task.copyWith(status: TaskStatus.cancelled),
          )) {
            throw StateError('Taskを分割できませんでした。');
          }
          await taskController.addTasks([
            for (final (index, value) in values.indexed)
              () {
                final data = Map<String, Object?>.from(value as Map);
                return QuestraTask(
                  questId: task.questId,
                  questTitle: task.questTitle,
                  missionId: task.missionId,
                  missionTitle: task.missionTitle,
                  title: data['title'] as String,
                  action: data['action'] as String,
                  purpose: task.purpose,
                  doneCondition: data['doneCondition'] as String,
                  expectedOutput: task.expectedOutput,
                  estimatedEffortMinutes:
                      data['estimatedEffortMinutes'] as int?,
                  required: task.required,
                  orderIndex: task.orderIndex + index,
                  generatedBy: TaskGeneratedBy.arc,
                  generationVersion: 'qst-279-v1',
                );
              }(),
          ]);
          break;
        }
        final original = missions
            .where((mission) => mission.id == item.targetMissionId)
            .firstOrNull;
        final values = item.afterData['missions'] as List?;
        if (original == null || values == null) return;
        missionController.archiveForRoute(original.id, persist: false);
        for (final (index, value) in values.indexed) {
          final data = Map<String, Object?>.from(value as Map);
          missionController.addMissionDraft(
            quest: quest,
            title: data['title'] as String,
            description: original.description,
            guideType: GuideType.route,
            difficulty: original.difficulty,
            sortOrder: original.sortOrder + index,
            parentMissionId: original.id,
            estimatedDurationDays: data['estimatedDays'] as int?,
            persist: false,
          );
        }
        break;
      case RouteChangeAction.pause:
      case RouteChangeAction.remove:
        final missionId = item.targetMissionId;
        if (missionId != null) {
          missionController.archiveForRoute(missionId, persist: false);
        }
        break;
      case RouteChangeAction.resume:
        final mission = missions
            .where((entry) => entry.id == item.targetMissionId)
            .firstOrNull;
        if (mission != null) {
          missionController.restoreForRoute(mission, persist: false);
        }
        break;
      case RouteChangeAction.add:
        final data = item.afterData['task'] as Map?;
        if (data != null && item.targetMissionId != null) {
          final mission = missions
              .where((entry) => entry.id == item.targetMissionId)
              .firstOrNull;
          if (mission != null && mission.status != MissionStatus.completed) {
            final value = Map<String, Object?>.from(data);
            await taskController.addTask(
              QuestraTask(
                questId: quest.id,
                questTitle: quest.title,
                missionId: mission.id,
                missionTitle: mission.title,
                title: value['title'] as String,
                action: value['action'] as String,
                purpose: value['purpose'] as String? ?? mission.objective,
                doneCondition: value['doneCondition'] as String,
                orderIndex: value['orderIndex'] as int? ?? 0,
                generatedBy: TaskGeneratedBy.arc,
                generationVersion: 'qst-279-v1',
              ),
            );
          }
        }
        break;
      case RouteChangeAction.merge:
      case RouteChangeAction.reestimate:
        // These actions require a richer AI payload or a fresh evaluation pass.
        break;
      case RouteChangeAction.replace:
        final original = missions
            .where((mission) => mission.id == item.targetMissionId)
            .firstOrNull;
        if (original == null || original.status == MissionStatus.completed) {
          return;
        }
        missionController.updateMission(
          original.copyWith(
            title: item.afterData['title'] as String?,
            description: item.afterData['description'] as String?,
            doneCondition: item.afterData['doneCondition'] as String?,
            expectedOutput: item.afterData['expectedOutput'] as String?,
            estimatedDurationDays:
                item.afterData['estimatedDurationDays'] as int?,
            difficultyScore: item.afterData['difficultyScore'] as int?,
            sourceRequirement: item.afterData['sourceRequirement'] as String?,
            confidence: (item.afterData['confidence'] as num?)?.toDouble(),
          ),
          persist: false,
        );
        break;
    }
  }

  Future<RouteUndoResult> undo(String proposalId) async {
    final questId =
        _undoProposals[proposalId]?.questId ?? _undoQuests[proposalId]?.id;
    if (questId != null &&
        (_acceptInProgress.contains(_operationKey(questId)) ||
            _acknowledgmentInProgress.contains(_operationKey(questId)) ||
            _undoBusyForQuest(questId))) {
      return const RouteUndoResult(
        RouteUndoStatus.busy,
        '航路を処理中です。完了までお待ちください。',
      );
    }
    if (!_undoInProgress.add(proposalId)) {
      return const RouteUndoResult(
        RouteUndoStatus.busy,
        '航路を元に戻しています。完了までお待ちください。',
      );
    }
    try {
      final repository = ref.read(routeReplanningRepositoryProvider);
      final proposal = _undoProposals[proposalId];
      if (repository.appliesProposalAtomically) {
        if (!_remoteRolledBack.contains(proposalId)) {
          final result = await repository.rollbackProposal(proposalId);
          if (result.status != RouteProposalStatus.rolledBack) {
            return RouteUndoResult(
              RouteUndoStatus.stale,
              result.staleReason ?? '航路が更新されています。内容を確認してからやり直してください。',
            );
          }
          _remoteRolledBack.add(proposalId);
        }
        try {
          await _reloadOwnedRoute();
        } catch (_) {
          return const RouteUndoResult(
            RouteUndoStatus.recoveryIncomplete,
            '航路は保存されましたが、画面の再読み込みを完了できませんでした。もう一度確認してください。',
          );
        }
      } else {
        final oldQuest = _undoQuests[proposalId];
        final oldMissions = _undoMissions[proposalId];
        final oldTasks = _undoTasks[proposalId];
        final applied = _undoAppliedSnapshots[proposalId];
        if (oldQuest == null ||
            oldMissions == null ||
            oldTasks == null ||
            applied == null ||
            _undoOwners[proposalId] !=
                ref.read(authControllerProvider).profile?.id) {
          return const RouteUndoResult(
            RouteUndoStatus.unavailable,
            '元に戻すための記録がありません。最新の航路を確認してください。',
          );
        }
        final currentQuest = ref
            .read(questControllerProvider)
            .where((entry) => entry.id == oldQuest.id)
            .firstOrNull;
        if (currentQuest == null) {
          return const RouteUndoResult(
            RouteUndoStatus.stale,
            'Questの状態が変わりました。最新の航路を確認してください。',
          );
        }
        final current = const RouteSnapshotService().capture(
          quest: currentQuest,
          missions: ref.read(missionControllerProvider),
          tasks: ref.read(taskControllerProvider),
        );
        final expected = _undoRecoverySnapshots[proposalId] ?? applied;
        if (const RouteSnapshotService().compare(expected, current).isStale) {
          return const RouteUndoResult(
            RouteUndoStatus.stale,
            '航路の適用後に進捗が変わりました。変更内容を確認してください。',
          );
        }
        final journalRepository = ref.read(
          routeMutationJournalRepositoryProvider,
        );
        final ownerId = _undoOwners[proposalId] ?? 'local-preview';
        final previousJournal = await journalRepository.load(
          ownerId,
          oldQuest.id,
        );
        if (previousJournal != null &&
            previousJournal.proposalId != proposalId) {
          return const RouteUndoResult(
            RouteUndoStatus.recoveryIncomplete,
            '前回の航路操作が残っています。現在の内容を確認してください。',
          );
        }
        final journal =
            previousJournal ??
            RouteMutationJournal(
              ownerId: ownerId,
              questId: oldQuest.id,
              proposalId: proposalId,
              stage: RouteJournalStage.recovering,
              beforeSnapshot: applied,
              afterSnapshot: const RouteSnapshotService().capture(
                quest: oldQuest,
                missions: oldMissions,
                tasks: oldTasks,
              ),
              createdAt: DateTime.now().toUtc(),
            );
        await journalRepository.save(
          journal.copyWith(
            stage: RouteJournalStage.recovering,
            attempts: journal.attempts + 1,
          ),
        );
        final restored = await _restoreLocalSnapshot(
          quest: oldQuest,
          missions: oldMissions,
          tasks: oldTasks,
        );
        if (!restored) {
          await journalRepository.save(
            journal.copyWith(
              stage: RouteJournalStage.recoveryNeeded,
              attempts: journal.attempts + 1,
            ),
          );
          _undoRecoverySnapshots[proposalId] = const RouteSnapshotService()
              .capture(
                quest:
                    ref
                        .read(questControllerProvider)
                        .where((entry) => entry.id == oldQuest.id)
                        .firstOrNull ??
                    oldQuest,
                missions: ref.read(missionControllerProvider),
                tasks: ref.read(taskControllerProvider),
              );
          return const RouteUndoResult(
            RouteUndoStatus.recoveryIncomplete,
            '一部を元に戻せませんでした。現在の航路を確認し、もう一度お試しください。',
          );
        }
        _undoRecoverySnapshots[proposalId] = const RouteSnapshotService()
            .capture(
              quest:
                  ref
                      .read(questControllerProvider)
                      .where((entry) => entry.id == oldQuest.id)
                      .firstOrNull ??
                  oldQuest,
              missions: ref.read(missionControllerProvider),
              tasks: ref.read(taskControllerProvider),
            );
        final result = await repository.rollbackProposal(proposalId);
        if (result.status != RouteProposalStatus.rolledBack) {
          await journalRepository.save(
            journal.copyWith(
              stage: RouteJournalStage.recoveryNeeded,
              attempts: journal.attempts + 1,
            ),
          );
          return const RouteUndoResult(
            RouteUndoStatus.recoveryIncomplete,
            '航路の復旧状態を確定できませんでした。内容を確認してください。',
          );
        }
        await journalRepository.clear(ownerId, oldQuest.id);
      }
      _undoProposals.remove(proposalId);
      _undoQuests.remove(proposalId);
      _undoMissions.remove(proposalId);
      _undoTasks.remove(proposalId);
      _undoAppliedSnapshots.remove(proposalId);
      _undoRecoverySnapshots.remove(proposalId);
      _undoOwners.remove(proposalId);
      _remoteRolledBack.remove(proposalId);
      if (proposal != null) {
        unawaited(
          ref
              .read(analyticsServiceProvider)
              .progress(
                name: AnalyticsEventName.routeRolledBack,
                userId: ref.read(authControllerProvider).profile?.id,
                questId: proposal.questId,
                routeId: proposal.routeVersionId,
              ),
        );
      }
      return const RouteUndoResult(RouteUndoStatus.restored, '航路を元に戻しました。');
    } catch (_) {
      return const RouteUndoResult(
        RouteUndoStatus.recoveryIncomplete,
        '航路を元に戻せませんでした。現在の内容を確認し、もう一度お試しください。',
      );
    } finally {
      _undoInProgress.remove(proposalId);
    }
  }

  Future<RouteUndoResult> retryFailedAcceptanceRecovery(
    String proposalId,
  ) async {
    final questId = _undoQuests[proposalId]?.id;
    if (questId != null &&
        (_acceptInProgress.contains(_operationKey(questId)) ||
            _acknowledgmentInProgress.contains(_operationKey(questId)) ||
            _undoBusyForQuest(questId))) {
      return const RouteUndoResult(RouteUndoStatus.busy, '航路の処理中です。少しお待ちください。');
    }
    if (!_undoInProgress.add(proposalId)) {
      return const RouteUndoResult(RouteUndoStatus.busy, '航路の復旧中です。少しお待ちください。');
    }
    try {
      final quest = _undoQuests[proposalId];
      final missions = _undoMissions[proposalId];
      final tasks = _undoTasks[proposalId];
      final ownerId = ref.read(authControllerProvider).profile?.id;
      if (quest == null ||
          missions == null ||
          tasks == null ||
          _undoOwners[proposalId] != ownerId) {
        return const RouteUndoResult(
          RouteUndoStatus.unavailable,
          '復旧に必要な記録がありません。現在の航路を確認してください。',
        );
      }
      final repository = ref.read(routeMutationJournalRepositoryProvider);
      final journal = await repository.load(
        ownerId ?? 'local-preview',
        quest.id,
      );
      if (journal == null ||
          journal.proposalId != proposalId ||
          journal.stage != RouteJournalStage.recoveryNeeded ||
          journal.afterSnapshot == null) {
        return const RouteUndoResult(
          RouteUndoStatus.unavailable,
          '前回の復旧記録を確認できません。現在の航路を確認してください。',
        );
      }
      final currentQuest = ref
          .read(questControllerProvider)
          .where((entry) => entry.id == quest.id)
          .firstOrNull;
      if (currentQuest == null) {
        return const RouteUndoResult(
          RouteUndoStatus.stale,
          'Questの状態が変わりました。最新の航路を確認してください。',
        );
      }
      final current = const RouteSnapshotService().capture(
        quest: currentQuest,
        missions: ref.read(missionControllerProvider),
        tasks: ref.read(taskControllerProvider),
      );
      if (const RouteSnapshotService()
          .compare(journal.afterSnapshot!, current)
          .isStale) {
        return const RouteUndoResult(
          RouteUndoStatus.stale,
          '前回の操作後に進捗が変わりました。内容を確認してください。',
        );
      }
      final restored = await _restoreLocalSnapshot(
        quest: quest,
        missions: missions,
        tasks: tasks,
      );
      if (!restored) {
        final latestQuest =
            ref
                .read(questControllerProvider)
                .where((entry) => entry.id == quest.id)
                .firstOrNull ??
            quest;
        await repository.save(
          journal.copyWith(
            attempts: journal.attempts + 1,
            afterSnapshot: const RouteSnapshotService().capture(
              quest: latestQuest,
              missions: ref.read(missionControllerProvider),
              tasks: ref.read(taskControllerProvider),
            ),
          ),
        );
        return const RouteUndoResult(
          RouteUndoStatus.recoveryIncomplete,
          '一部を戻せませんでした。現在の内容を確認してから、もう一度お試しください。',
        );
      }
      await repository.clear(ownerId ?? 'local-preview', quest.id);
      if (await repository.load(ownerId ?? 'local-preview', quest.id) != null) {
        return const RouteUndoResult(
          RouteUndoStatus.recoveryIncomplete,
          '復旧記録を整理できませんでした。現在の航路を確認してください。',
        );
      }
      _undoQuests.remove(proposalId);
      _undoMissions.remove(proposalId);
      _undoTasks.remove(proposalId);
      _undoOwners.remove(proposalId);
      return const RouteUndoResult(RouteUndoStatus.restored, '承認前の航路へ戻しました。');
    } catch (_) {
      return const RouteUndoResult(
        RouteUndoStatus.recoveryIncomplete,
        '航路の復旧を完了できませんでした。現在の内容を確認してください。',
      );
    } finally {
      _undoInProgress.remove(proposalId);
    }
  }

  Future<RouteJournalDisposition?> inspectLocalJournal(
    Quest quest,
    List<Mission> missions,
  ) async {
    return (await inspectRouteJournal(quest, missions))?.disposition;
  }

  Future<RouteJournalInspection?> inspectRouteJournal(
    Quest quest,
    List<Mission> missions,
  ) async {
    final ownerId =
        ref.read(authControllerProvider).profile?.id ?? 'local-preview';
    final journal = await ref
        .read(routeMutationJournalRepositoryProvider)
        .load(ownerId, quest.id);
    if (journal == null) return null;
    final current = const RouteSnapshotService().capture(
      quest: quest,
      missions: missions,
      tasks: ref.read(taskControllerProvider),
    );
    return RouteJournalInspection(
      proposalId: journal.proposalId,
      stage: journal.stage,
      disposition: journal.disposition(current),
      createdAt: journal.createdAt,
      matchesBefore: !const RouteSnapshotService()
          .compare(journal.beforeSnapshot, current)
          .isStale,
      matchesAfter:
          journal.afterSnapshot != null &&
          !const RouteSnapshotService()
              .compare(journal.afterSnapshot!, current)
              .isStale,
    );
  }

  Future<bool> acknowledgeRouteJournal(
    String questId,
    String proposalId,
  ) async {
    final operationKey = _operationKey(questId);
    if (_acceptInProgress.contains(operationKey) ||
        _undoBusyForQuest(questId) ||
        !_acknowledgmentInProgress.add(operationKey)) {
      return false;
    }
    try {
      return await _acknowledgeRouteJournal(questId, proposalId);
    } finally {
      _acknowledgmentInProgress.remove(operationKey);
    }
  }

  Future<bool> _acknowledgeRouteJournal(
    String questId,
    String proposalId,
  ) async {
    final ownerId =
        ref.read(authControllerProvider).profile?.id ?? 'local-preview';
    final repository = ref.read(routeMutationJournalRepositoryProvider);
    final journal = await repository.load(ownerId, questId);
    if (journal == null || journal.proposalId != proposalId) return false;
    final quest = ref
        .read(questControllerProvider)
        .where((item) => item.id == questId)
        .firstOrNull;
    if (quest == null) return false;
    final current = const RouteSnapshotService().capture(
      quest: quest,
      missions: ref.read(missionControllerProvider),
      tasks: ref.read(taskControllerProvider),
    );
    final inspection = RouteJournalInspection(
      proposalId: journal.proposalId,
      stage: journal.stage,
      disposition: journal.disposition(current),
      createdAt: journal.createdAt,
      matchesBefore: !const RouteSnapshotService()
          .compare(journal.beforeSnapshot, current)
          .isStale,
      matchesAfter:
          journal.afterSnapshot != null &&
          !const RouteSnapshotService()
              .compare(journal.afterSnapshot!, current)
              .isStale,
    );
    if (!inspection.canAcknowledge) return false;
    await repository.clear(ownerId, questId);
    if (await repository.load(ownerId, questId) != null) return false;
    if (journal.stage != RouteJournalStage.applied) {
      _undoProposals.remove(proposalId);
      _undoQuests.remove(proposalId);
      _undoMissions.remove(proposalId);
      _undoTasks.remove(proposalId);
      _undoAppliedSnapshots.remove(proposalId);
      _undoRecoverySnapshots.remove(proposalId);
      _undoOwners.remove(proposalId);
      _remoteRolledBack.remove(proposalId);
      if (state[questId]?.id == proposalId) {
        state = Map.of(state)..remove(questId);
      }
    }
    return true;
  }

  Future<void> _reloadOwnedRoute() async {
    final userId = ref.read(authControllerProvider).profile?.id;
    if (userId == null) {
      throw StateError('航路を再読み込みするにはログインが必要です。');
    }
    await ref.read(questControllerProvider.notifier).loadForUser(userId);
    final questIds = ref
        .read(questControllerProvider)
        .map((quest) => quest.id)
        .toList(growable: false);
    await ref.read(missionControllerProvider.notifier).loadForQuests(questIds);
    await ref.read(taskControllerProvider.notifier).loadForQuestIds(questIds);
  }
}
