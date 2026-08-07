import '../mission/mission_model.dart';
import '../quest/quest_model.dart';

enum QuestLifecycleStage {
  dreaming,
  exploring,
  planning,
  preparing,
  acting,
  nearCompletion,
  completed,
  paused,
  abandoned,
}

enum QuestStageSource { user, arc, system }

extension QuestLifecycleStageValue on QuestLifecycleStage {
  String get storageKey =>
      this == QuestLifecycleStage.nearCompletion ? 'near_completion' : name;
  String get label => switch (this) {
    QuestLifecycleStage.dreaming => '思い描く',
    QuestLifecycleStage.exploring => '探る',
    QuestLifecycleStage.planning => '航路を描く',
    QuestLifecycleStage.preparing => '準備する',
    QuestLifecycleStage.acting => '進む',
    QuestLifecycleStage.nearCompletion => '達成間近',
    QuestLifecycleStage.completed => '達成',
    QuestLifecycleStage.paused => '一時休止',
    QuestLifecycleStage.abandoned => '終了',
  };
}

class QuestStageDecision {
  const QuestStageDecision({
    required this.stage,
    required this.source,
    required this.confidence,
    required this.reasonCode,
  });
  final QuestLifecycleStage stage;
  final QuestStageSource source;
  final double confidence;
  final String reasonCode;
}

class QuestLifecycleStageService {
  const QuestLifecycleStageService();
  QuestStageDecision infer(Quest quest, List<Mission> missions) {
    if (quest.status == QuestStatus.completed || quest.progress >= 1) {
      return const QuestStageDecision(
        stage: QuestLifecycleStage.completed,
        source: QuestStageSource.system,
        confidence: 1,
        reasonCode: 'success_confirmed',
      );
    }
    final active = missions.where((m) => m.questId == quest.id).toList();
    final completed = active
        .where((m) => m.status == MissionStatus.completed)
        .length;
    final ratio = active.isEmpty ? quest.progress : completed / active.length;
    if (ratio >= 0.8) {
      return const QuestStageDecision(
        stage: QuestLifecycleStage.nearCompletion,
        source: QuestStageSource.system,
        confidence: 0.9,
        reasonCode: 'required_missions_almost_complete',
      );
    }
    if (ratio > 0) {
      return const QuestStageDecision(
        stage: QuestLifecycleStage.acting,
        source: QuestStageSource.system,
        confidence: 0.85,
        reasonCode: 'mission_progress_detected',
      );
    }
    if (active.isNotEmpty) {
      return const QuestStageDecision(
        stage: QuestLifecycleStage.preparing,
        source: QuestStageSource.arc,
        confidence: 0.75,
        reasonCode: 'route_ready',
      );
    }
    if (quest.understanding != null || quest.targetDate != null) {
      return const QuestStageDecision(
        stage: QuestLifecycleStage.planning,
        source: QuestStageSource.arc,
        confidence: 0.7,
        reasonCode: 'success_contract_in_progress',
      );
    }
    return const QuestStageDecision(
      stage: QuestLifecycleStage.dreaming,
      source: QuestStageSource.system,
      confidence: 0.65,
      reasonCode: 'safe_default',
    );
  }

  bool canAutoTransitionTo(QuestLifecycleStage stage) =>
      stage != QuestLifecycleStage.abandoned &&
      stage != QuestLifecycleStage.paused;
}
