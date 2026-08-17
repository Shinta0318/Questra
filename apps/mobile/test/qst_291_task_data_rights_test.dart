import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/theme/app_theme.dart';
import 'package:questra/features/task/task_controller.dart';
import 'package:questra/features/task/task_model.dart';
import 'package:questra/features/trust/data_rights_repository.dart';
import 'package:questra/features/trust/data_rights_screen.dart';

void main() {
  testWidgets('本人用export件数とTask削除の影響を確認できる', (tester) async {
    final repository = _FakeDataRightsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataRightsRepositoryProvider.overrideWithValue(repository),
          taskControllerProvider.overrideWith(_DataRightsTaskController.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const DataRightsScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('作成'));
    await tester.pumpAndSettle();
    expect(find.textContaining('tasks: 1件'), findsOneWidget);
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -420));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('削除の影響を確認'));
    await tester.tap(find.byTooltip('削除の影響を確認'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Trail 2件は記録として残り'), findsOneWidget);
    expect(find.textContaining('Arc Memory 1件は削除'), findsOneWidget);
    await tester.tap(find.text('やめる'));
    await tester.pumpAndSettle();
    expect(repository.deleted, isFalse);
  });

  test('data rights migrationはowner限定exportとtransaction削除を持つ', () {
    final sql = File(
      '../../supabase/migrations/202608090002_task_data_rights_operations.sql',
    ).readAsStringSync();

    expect(sql, contains('v_owner uuid := auth.uid()'));
    expect(sql, contains('where t.owner_id = v_owner'));
    expect(sql, contains("'tasks', v_tasks"));
    expect(sql, contains("'trails_preserved_and_unlinked'"));
    expect(sql, contains("'arc_memories_deleted'"));
    expect(sql, contains("p_confirmation is distinct from 'DELETE:'"));
    expect(sql, contains('data_rights_audit_events'));
    expect(sql, contains('grant execute on function'));
  });
}

class _DataRightsTaskController extends TaskController {
  @override
  List<QuestraTask> build() => [
    QuestraTask(
      id: 'task-1',
      questId: 'quest-1',
      missionId: 'mission-1',
      questTitle: '星を目指す',
      missionTitle: '準備する',
      title: '必要な情報を確認する',
      action: '公式情報を一つ確認する',
      doneCondition: '確認結果が保存されている',
    ),
  ];
}

class _FakeDataRightsRepository implements DataRightsRepository {
  bool deleted = false;

  @override
  Future<void> deleteTask(TaskDeletionPreview preview) async {
    deleted = true;
  }

  @override
  Future<DataExportManifest> exportMyData() async => DataExportManifest(
    version: 1,
    generatedAt: DateTime.utc(2026, 8, 9),
    counts: const {'tasks': 1, 'trails': 2, 'arc_memories': 1},
    payload: const {},
  );

  @override
  Future<TaskDeletionPreview> previewTaskDeletion(String taskId) async =>
      const TaskDeletionPreview(
        taskId: 'task-1',
        taskTitle: '必要な情報を確認する',
        trailCount: 2,
        memoryCount: 1,
      );

  @override
  Future<List<DataRightsRequest>> listRequests() async => const [];

  @override
  Future<DataRightsRequest> requestAccountDeletion({
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<DataRightsRequest> cancelRequest(String requestId) =>
      throw UnimplementedError();
}
