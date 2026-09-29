import '../mission/mission_model.dart';
import '../quest/quest_model.dart';
import '../task/task_model.dart';
import 'trail_model.dart';

enum TrailParentValidationStatus { valid, unresolved, invalid }

class TrailParentValidation {
  const TrailParentValidation(this.status, {this.reason});

  final TrailParentValidationStatus status;
  final String? reason;

  bool get canProceed => status != TrailParentValidationStatus.invalid;
}

class TrailParentValidator {
  const TrailParentValidator();

  TrailParentValidation validate({
    required TrailParentContext parent,
    required Iterable<Quest> quests,
    required Iterable<Mission> missions,
    required Iterable<QuestraTask> tasks,
  }) {
    if (!parent.isStructurallyValid) {
      return const TrailParentValidation(
        TrailParentValidationStatus.invalid,
        reason: 'Trailの紐づけ情報が不足しています。',
      );
    }
    final questList = quests.toList(growable: false);
    final missionList = missions.toList(growable: false);
    final taskList = tasks.toList(growable: false);
    if (questList.isEmpty && missionList.isEmpty && taskList.isEmpty) {
      return const TrailParentValidation(
        TrailParentValidationStatus.unresolved,
        reason: '親データの読込後にサーバーで再確認します。',
      );
    }

    final quest = questList
        .where((item) => item.id == parent.questId)
        .firstOrNull;
    if (quest == null || quest.status == QuestStatus.archived) {
      return const TrailParentValidation(
        TrailParentValidationStatus.invalid,
        reason: '選択したQuestへTrailを追加できません。',
      );
    }

    Mission? mission;
    if (parent.missionId case final missionId?) {
      mission = missionList
          .where(
            (item) =>
                item.id == missionId &&
                item.questId == parent.questId &&
                item.routeState != MissionRouteState.removed,
          )
          .firstOrNull;
      if (mission == null) {
        return const TrailParentValidation(
          TrailParentValidationStatus.invalid,
          reason: '選択したMissionはこのQuestに紐づいていません。',
        );
      }
    }

    if (parent.taskId case final taskId?) {
      final task = taskList
          .where(
            (item) =>
                item.id == taskId &&
                item.questId == parent.questId &&
                item.missionId == mission?.id,
          )
          .firstOrNull;
      if (task == null) {
        return const TrailParentValidation(
          TrailParentValidationStatus.invalid,
          reason: '選択したTaskはこのMissionに紐づいていません。',
        );
      }
    }

    return const TrailParentValidation(TrailParentValidationStatus.valid);
  }
}

class TrailParentMutationPolicy {
  const TrailParentMutationPolicy();

  bool canApply({
    required Trail previous,
    required Trail updated,
    required Iterable<Quest> quests,
    required Iterable<Mission> missions,
    required Iterable<QuestraTask> tasks,
  }) {
    final parentUnchanged =
        previous.questId == updated.questId &&
        previous.missionId == updated.missionId &&
        previous.taskId == updated.taskId;
    if (parentUnchanged) return true;
    if (previous.taskId != null || updated.taskId != null) return false;
    final questId = updated.questId;
    final missionId = updated.missionId;
    if (questId == null || missionId == null) return false;
    final quest = quests.where((item) => item.id == questId).firstOrNull;
    final mission = missions
        .where((item) => item.id == missionId && item.questId == questId)
        .firstOrNull;
    if (quest == null || mission == null) return false;
    final validation = const TrailParentValidator().validate(
      parent: TrailParentContext(
        questId: quest.id,
        questTitle: quest.title,
        missionId: mission.id,
        missionTitle: mission.title,
      ),
      quests: quests,
      missions: missions,
      tasks: tasks,
    );
    return validation.status == TrailParentValidationStatus.valid;
  }
}
