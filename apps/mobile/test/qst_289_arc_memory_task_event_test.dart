import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc_memory/arc_memory_model.dart';
import 'package:questra/features/arc_memory/arc_memory_repository.dart';
import 'package:questra/features/arc_memory/memory_extraction_service.dart';
import 'package:questra/features/arc_memory/task_memory_event_service.dart';
import 'package:questra/features/task/task_model.dart';

void main() {
  test('同意済みのTask開始を親Quest・Mission付きMemoryへ保存する', () async {
    final repository = InMemoryArcMemoryRepository();
    final service = TaskMemoryEventService(
      MemoryExtractionService(repository: repository),
    );
    final memories = await service.recordTransition(
      userId: 'owner-a',
      previous: _task(status: TaskStatus.pending),
      current: _task(status: TaskStatus.inProgress),
      consentGranted: true,
    );

    expect(memories.single.memoryType, ArcMemoryType.taskMemory);
    expect(memories.single.sourceType, ArcMemorySourceType.taskStarted);
    expect(memories.single.taskId, 'task-1');
    expect(memories.single.questId, 'quest-1');
    expect(memories.single.missionId, 'mission-1');
  });

  test('Arcパーソナライズ同意がなければTaskイベントを保存しない', () async {
    final repository = InMemoryArcMemoryRepository();
    final service = TaskMemoryEventService(
      MemoryExtractionService(repository: repository),
    );

    final memories = await service.recordTransition(
      userId: 'owner-a',
      previous: _task(status: TaskStatus.inProgress),
      current: _task(status: TaskStatus.completed),
      consentGranted: false,
    );

    expect(memories, isEmpty);
    expect(await repository.findByUser('owner-a'), isEmpty);
  });

  test('Task完了と延期を別のイベントとして記憶する', () async {
    final repository = InMemoryArcMemoryRepository();
    final service = TaskMemoryEventService(
      MemoryExtractionService(repository: repository),
    );
    final completed = await service.recordTransition(
      userId: 'owner-a',
      previous: _task(status: TaskStatus.inProgress),
      current: _task(status: TaskStatus.completed),
      consentGranted: true,
    );
    final postponed = await service.recordTransition(
      userId: 'owner-a',
      previous: _task(status: TaskStatus.pending),
      current: _task(
        status: TaskStatus.pending,
        scheduledDate: DateTime(2026, 8, 10),
      ),
      consentGranted: true,
    );

    expect(completed.single.sourceType, ArcMemorySourceType.taskCompleted);
    expect(postponed.single.sourceType, ArcMemorySourceType.taskRescheduled);
    expect(completed.single.dedupeKey, isNot(postponed.single.dedupeKey));
  });

  test('Task削除要求は同じ所有者の関連Memoryだけを削除する', () async {
    final repository = InMemoryArcMemoryRepository();
    await repository.save(_memory(userId: 'owner-a'));
    await repository.save(_memory(userId: 'owner-b'));

    await repository.deleteByTaskId('owner-a', 'task-1');

    expect(await repository.findByUser('owner-a'), isEmpty);
    expect(await repository.findByUser('owner-b'), hasLength(1));
  });

  test('migrationはTask owner整合、RLS維持、削除連鎖を要求する', () {
    final sql = File(
      '../../supabase/migrations/202608090001_arc_memory_task_events.sql',
    ).readAsStringSync();

    expect(sql, contains('references public.tasks(id) on delete cascade'));
    expect(sql, contains('t.owner_id = new.user_id'));
    expect(sql, contains('t.quest_id = new.quest_id'));
    expect(sql, contains('t.mission_id = new.mission_id'));
    expect(sql, contains('arc_memory_task_context_guard'));
  });
}

QuestraTask _task({required TaskStatus status, DateTime? scheduledDate}) =>
    QuestraTask(
      id: 'task-1',
      questId: 'quest-1',
      missionId: 'mission-1',
      questTitle: '星を目指す',
      missionTitle: '準備する',
      title: '必要な情報を確認する',
      action: '公式情報を一つ確認する',
      doneCondition: '確認結果が保存されている',
      status: status,
      scheduledDate: scheduledDate,
    );

ArcMemory _memory({required String userId}) => ArcMemory(
  userId: userId,
  questId: 'quest-1',
  missionId: 'mission-1',
  taskId: 'task-1',
  memoryType: ArcMemoryType.taskMemory,
  title: 'Taskの記憶',
  content: 'Taskを完了して航路を一歩進めた。',
  importanceScore: 0.7,
  emotionalTone: EmotionalTone.positive,
  sourceType: ArcMemorySourceType.taskCompleted,
  sourceId: 'task-1',
);
