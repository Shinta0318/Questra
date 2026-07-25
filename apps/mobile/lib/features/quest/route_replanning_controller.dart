import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../mission/mission_controller.dart';
import '../mission/mission_model.dart';
import '../auth/auth_controller.dart';
import 'adaptive_route_service.dart';
import 'quest_controller.dart';
import 'quest_guide_model.dart';
import 'quest_model.dart';
import 'route_replanning_model.dart';
import 'route_replanning_repository.dart';
import 'route_replanning_trigger_service.dart';

final routeReplanningControllerProvider =
    NotifierProvider<
      RouteReplanningController,
      Map<String, RouteChangeProposal>
    >(RouteReplanningController.new);

class RouteReplanningController
    extends Notifier<Map<String, RouteChangeProposal>> {
  final Map<String, List<Mission>> _undoMissions = {};
  final Map<String, Quest> _undoQuests = {};
  final Map<String, DateTime> _lastEvaluatedAt = {};

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
    return const {};
  }

  Future<RouteChangeProposal?> review(
    Quest quest,
    List<Mission> missions,
  ) async {
    return _reviewWithTrigger(quest, missions, RouteReplanningTrigger.manual);
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
    );
    if (proposal == null) return null;
    await ref.read(routeReplanningRepositoryProvider).saveProposal(proposal);
    _lastEvaluatedAt[quest.id] = DateTime.now();
    state = {...state, quest.id: proposal};
    return proposal;
  }

  Future<void> reject(RouteChangeProposal proposal) async {
    await ref
        .read(routeReplanningRepositoryProvider)
        .resolveProposal(proposal.id, RouteProposalStatus.rejected);
    state = Map.of(state)..remove(proposal.questId);
  }

  Future<void> accept(
    Quest quest,
    List<Mission> missions,
    RouteChangeProposal proposal,
    Set<String> acceptedItemIds,
  ) async {
    final selected = proposal.items
        .where((item) => acceptedItemIds.contains(item.id))
        .toList(growable: false);
    if (selected.isEmpty) return;
    final result = await ref
        .read(routeReplanningRepositoryProvider)
        .applyProposal(
          proposal: proposal,
          acceptedItemIds: selected.map((item) => item.id).toList(),
        );
    if (result.persistedAtomically) {
      await _reloadOwnedRoute();
    } else {
      _undoMissions[proposal.id] = List<Mission>.of(missions);
      _undoQuests[proposal.id] = quest;
      for (final item in selected) {
        _applyItem(quest, missions, item);
      }
    }
    state = Map.of(state)..remove(proposal.questId);
  }

  void _applyItem(Quest quest, List<Mission> missions, RouteChangeItem item) {
    final missionController = ref.read(missionControllerProvider.notifier);
    switch (item.action) {
      case RouteChangeAction.reschedule:
        final value = item.afterData['targetDate'] as String?;
        if (value != null) {
          ref
              .read(questControllerProvider.notifier)
              .update(quest.copyWith(targetDate: DateTime.tryParse(value)));
        }
        break;
      case RouteChangeAction.reorder:
        final missionId = item.targetMissionId;
        if (missionId != null) missionController.setToday(quest.id, missionId);
        break;
      case RouteChangeAction.split:
        final original = missions
            .where((mission) => mission.id == item.targetMissionId)
            .firstOrNull;
        final values = item.afterData['missions'] as List?;
        if (original == null || values == null) return;
        missionController.archiveForRoute(original.id);
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
          );
        }
        break;
      case RouteChangeAction.pause:
      case RouteChangeAction.remove:
        final missionId = item.targetMissionId;
        if (missionId != null) missionController.archiveForRoute(missionId);
        break;
      case RouteChangeAction.resume:
        final mission = missions
            .where((entry) => entry.id == item.targetMissionId)
            .firstOrNull;
        if (mission != null) missionController.restoreForRoute(mission);
        break;
      case RouteChangeAction.add:
      case RouteChangeAction.replace:
      case RouteChangeAction.merge:
      case RouteChangeAction.reestimate:
        // These actions require a richer AI payload or a fresh evaluation pass.
        break;
    }
  }

  Future<void> undo(String proposalId) async {
    final result = await ref
        .read(routeReplanningRepositoryProvider)
        .rollbackProposal(proposalId);
    if (result.persistedAtomically) {
      await _reloadOwnedRoute();
      return;
    }
    final oldMissions = _undoMissions.remove(proposalId);
    final oldQuest = _undoQuests.remove(proposalId);
    if (oldMissions == null || oldQuest == null) return;
    ref.read(questControllerProvider.notifier).update(oldQuest);
    final current = ref.read(missionControllerProvider);
    final oldIds = oldMissions.map((mission) => mission.id).toSet();
    for (final mission in current.where(
      (mission) =>
          mission.questId == oldQuest.id && !oldIds.contains(mission.id),
    )) {
      ref.read(missionControllerProvider.notifier).archiveForRoute(mission.id);
    }
    for (final mission in oldMissions) {
      ref.read(missionControllerProvider.notifier).restoreForRoute(mission);
    }
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
  }
}
