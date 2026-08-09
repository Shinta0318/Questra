import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc/arc_chat_service.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/task/task_model.dart';

void main() {
  test('local Arc uses an open Task and its done condition', () async {
    final response = await const LocalArcChatService().send(
      userMessage: '次に何をすればいい？',
      history: const [],
      context: ArcChatContext(
        activeQuests: [
          Quest(
            id: 'quest-1',
            title: 'シンガポールへ行く',
            description: '旅行を実現する',
            difficulty: QuestDifficulty.normal,
            status: QuestStatus.active,
            visibility: QuestVisibility.private,
          ),
        ],
        recentMissions: const [],
        recentTasks: [
          QuestraTask(
            id: 'task-1',
            questId: 'quest-1',
            missionId: 'mission-1',
            title: 'パスポートの期限を確認する',
            action: 'パスポートを開く',
            doneCondition: '有効期限を記録している',
            status: TaskStatus.ready,
          ),
        ],
        recentTrails: const [],
        memories: const [],
      ),
    );

    expect(response.message, contains('パスポートの期限を確認する'));
    expect(response.message, contains('有効期限を記録している'));
  });

  test(
    'Arc Edge contract keeps Mission and Task responsibilities distinct',
    () {
      final source = File(
        '../../supabase/functions/arc-chat/index.ts',
      ).readAsStringSync();

      expect(source, contains('recent_tasks'));
      expect(
        source,
        contains('A Mission is a verifiable intermediate outcome'),
      );
      expect(source, contains('A Task is the smallest concrete action'));
      expect(source, isNot(contains('A Mission is one observable action')));
      expect(source, isNot(contains('temperature:')));
    },
  );
}
