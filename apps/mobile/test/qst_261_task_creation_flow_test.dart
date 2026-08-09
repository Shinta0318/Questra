import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/task/task_generation_service.dart';
import 'package:questra/features/task/task_model.dart';
import 'package:questra/features/task/task_repository.dart';

void main() {
  test(
    'local Task proposal remains specific to its Mission contract',
    () async {
      final mission = Mission(
        id: 'mission-1',
        questId: 'quest-1',
        questTitle: '富士山に登る',
        title: '安全な登山計画が整っている',
        description: '候補日、登山ルート、同行者を決める',
        objective: '安全に実行できる計画を整える',
        successCondition: '候補日とルートを記録できたら完了',
        expectedOutcome: '確認できる登山計画',
        action: '候補日、登山ルート、同行者を決める',
        guideType: GuideType.route,
        difficulty: MissionDifficulty.normal,
        status: MissionStatus.todo,
      );

      final suggestions = await const LocalTaskGenerationService()
          .generateForMission(mission);

      expect(suggestions, hasLength(1));
      expect(suggestions.single.title, contains('候補日'));
      expect(suggestions.single.doneCondition, contains('記録'));
      expect(suggestions.single.estimatedEffortMinutes, greaterThan(0));
    },
  );

  test(
    'Task batch save can be reloaded with dependency order intact',
    () async {
      final repository = InMemoryTaskRepository();
      final tasks = [
        QuestraTask(
          id: 'task-1',
          questId: 'quest-1',
          missionId: 'mission-1',
          title: '候補日を出す',
          action: '候補日を3つ書き出す',
          doneCondition: '候補日が3つ記録されている',
          orderIndex: 0,
        ),
        QuestraTask(
          id: 'task-2',
          questId: 'quest-1',
          missionId: 'mission-1',
          title: '日程を決める',
          action: '候補日から実行日を選ぶ',
          doneCondition: '実行日が1つ記録されている',
          dependencyIds: const ['task-1'],
          orderIndex: 1,
        ),
      ];

      await repository.saveAll(tasks);
      final reloaded = await repository.findByMission('mission-1');

      expect(reloaded.map((task) => task.id), ['task-1', 'task-2']);
      expect(reloaded.last.dependencyIds, ['task-1']);
    },
  );

  test('Mission detail exposes generation, manual add, retry and approval', () {
    final root =
        Directory.current.path.endsWith('${Platform.pathSeparator}mobile')
        ? Directory.current.parent.parent
        : Directory.current;
    final source = File(
      '${root.path}/apps/mobile/lib/features/mission/mission_detail_screen.dart',
    ).readAsStringSync();
    final endpoint = File(
      '${root.path}/supabase/functions/quest-planning-v2/index.ts',
    ).readAsStringSync();
    final pipeline = File(
      '${root.path}/supabase/functions/_shared/quest_planning/pipeline.ts',
    ).readAsStringSync();
    final validators = File(
      '${root.path}/supabase/functions/_shared/quest_planning/validators.ts',
    ).readAsStringSync();

    expect(source, contains('Arcに提案してもらう'));
    expect(source, contains('自分で追加'));
    expect(source, contains('_TaskSuggestionDialog'));
    expect(source, contains('addTasks(tasks)'));
    expect(endpoint, contains('expand_tasks'));
    expect(endpoint, contains('if (!await ownsQuest(auth, userId, questId))'));
    expect(endpoint, contains('userFetch(auth'));
    expect(
      endpoint,
      isNot(
        contains(
          'missions?id=eq.\${missionId}&quest_id=eq.\${questId}&owner_id=',
        ),
      ),
    );
    expect(pipeline, contains('runTaskExpansionPipeline'));
    expect(pipeline, contains('"task_critic"'));
    expect(pipeline, contains('"task_repair"'));
    expect(validators, contains('Task dependency graph contains a cycle'));
    expect(validators, contains('Task cannot depend on itself'));
  });
}
