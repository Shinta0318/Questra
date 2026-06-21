import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'quest_controller.dart';
import 'quest_milestone_model.dart';
import 'quest_providers.dart';

final questMilestoneControllerProvider =
    NotifierProvider<
      QuestMilestoneController,
      Map<String, List<QuestMilestone>>
    >(QuestMilestoneController.new);

class QuestMilestoneController
    extends Notifier<Map<String, List<QuestMilestone>>> {
  @override
  Map<String, List<QuestMilestone>> build() {
    ref.listen(authControllerProvider.select((state) => state.profile?.id), (
      previous,
      next,
    ) {
      if (next != null && next != previous) {
        _loadForCurrentQuests();
      }
    });

    ref.listen(questControllerProvider, (previous, next) {
      if (ref.read(authControllerProvider).profile != null) {
        unawaited(loadForQuests(next.map((quest) => quest.id).toList()));
      }
    });

    if (ref.read(authControllerProvider).profile != null) {
      unawaited(Future<void>.microtask(_loadForCurrentQuests));
    }

    return const {};
  }

  List<QuestMilestone> forQuest(String questId) {
    return state[questId] ?? const [];
  }

  Future<void> loadForQuests(List<String> questIds) async {
    if (questIds.isEmpty) {
      state = const {};
      return;
    }

    try {
      final milestones = await ref
          .read(questMilestoneRepositoryProvider)
          .findByQuestIds(questIds);
      final next = <String, List<QuestMilestone>>{};
      for (final milestone in milestones) {
        next.putIfAbsent(milestone.questId, () => []).add(milestone);
      }
      state = {...state, ...next};
    } catch (_) {
      // Milestones are progressive planning support; generated local plans stay usable.
    }
  }

  Future<void> saveGeneratedPlan(List<QuestMilestone> milestones) async {
    final userId = ref.read(authControllerProvider).profile?.id;
    if (userId == null || milestones.isEmpty) {
      return;
    }
    try {
      final saved = await ref
          .read(questMilestoneRepositoryProvider)
          .saveAll(ownerId: userId, milestones: milestones);
      _merge(saved);
    } catch (_) {
      // Keep generated milestones visible even when persistence is unavailable.
    }
  }

  Future<void> updateStatus(
    QuestMilestone milestone,
    QuestMilestoneStatus status,
  ) async {
    final progress = status == QuestMilestoneStatus.completed
        ? 1.0
        : status == QuestMilestoneStatus.active
        ? milestone.progress.clamp(0.25, 0.75).toDouble()
        : 0.0;
    final updated = milestone.copyWith(status: status, progress: progress);
    _merge([updated]);

    final userId = ref.read(authControllerProvider).profile?.id;
    if (userId == null) {
      return;
    }

    try {
      final saved = await ref
          .read(questMilestoneRepositoryProvider)
          .save(ownerId: userId, milestone: updated);
      _merge([saved]);
    } catch (_) {
      // UI already reflects the local planning action.
    }
  }

  void _loadForCurrentQuests() {
    final questIds = ref
        .read(questControllerProvider)
        .map((quest) => quest.id)
        .toList(growable: false);
    unawaited(loadForQuests(questIds));
  }

  void _merge(List<QuestMilestone> milestones) {
    final next = {
      for (final entry in state.entries) entry.key: [...entry.value],
    };
    for (final milestone in milestones) {
      final list = next.putIfAbsent(milestone.questId, () => []);
      list.removeWhere((current) => current.id == milestone.id);
      list.add(milestone);
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    state = next;
  }
}
