import '../task/task_model.dart';
import 'arc_memory_model.dart';
import 'memory_extraction_service.dart';

class TaskMemoryEventService {
  const TaskMemoryEventService(this.extractionService);

  final MemoryExtractionService extractionService;

  Future<List<ArcMemory>> recordTransition({
    required String userId,
    required QuestraTask? previous,
    required QuestraTask current,
    required bool consentGranted,
  }) async {
    if (!consentGranted || previous == null) return const [];
    final sourceType = _sourceType(previous, current);
    if (sourceType == null) return const [];
    final eventLabel = switch (sourceType) {
      ArcMemorySourceType.taskStarted => '開始した',
      ArcMemorySourceType.taskCompleted => '完了した',
      ArcMemorySourceType.taskRescheduled => '予定を見直した',
      _ => '',
    };
    return extractionService.extractAndSave(
      MemoryExtractionEvent(
        userId: userId,
        questId: current.questId,
        missionId: current.missionId,
        taskId: current.id,
        sourceId: current.id,
        sourceType: sourceType,
        title: 'Taskの記憶',
        text:
            'Task「${current.title}」を$eventLabel。親Missionは「${current.missionTitle}」。',
        metadata: {
          'status': current.status.storageKey,
          'scheduled_date': current.scheduledDate?.toIso8601String(),
          'consent_purpose': 'arc_personalization',
        },
      ),
    );
  }

  ArcMemorySourceType? _sourceType(QuestraTask previous, QuestraTask current) {
    if (previous.status != TaskStatus.completed &&
        current.status == TaskStatus.completed) {
      return ArcMemorySourceType.taskCompleted;
    }
    if (previous.status != TaskStatus.inProgress &&
        current.status == TaskStatus.inProgress) {
      return ArcMemorySourceType.taskStarted;
    }
    if (previous.scheduledDate != current.scheduledDate &&
        current.scheduledDate != null) {
      return ArcMemorySourceType.taskRescheduled;
    }
    return null;
  }
}
