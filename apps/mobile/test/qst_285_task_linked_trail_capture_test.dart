import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:questra/core/router/app_routes.dart';
import 'package:questra/features/trail/trail_controller.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/features/trail/trail_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ja_JP'));

  const parent = TrailParentContext(
    questId: 'quest-1',
    questTitle: 'シンガポールへ行く',
    missionId: 'mission-1',
    missionTitle: '渡航準備を整える',
    taskId: 'task-1',
    taskTitle: 'パスポートの有効期限を確認する',
  );

  testWidgets('Task起点のTrail作成は親階層を表示して保存する', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: TrailScreen(initialParent: parent, openComposer: true),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Quest: シンガポールへ行く'), findsOneWidget);
    expect(find.text('Mission: 渡航準備を整える'), findsOneWidget);
    expect(find.text('Task: パスポートの有効期限を確認する'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '期限を確認した');
    await tester.enterText(fields.at(1), '有効期限に余裕があると分かった');
    await tester.enterText(fields.at(2), '次は航空券の条件を整理する。');
    await tester.ensureVisible(find.text('Trailを保存'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Trailを保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final trail = container.read(trailControllerProvider).single;
    expect(trail.questId, parent.questId);
    expect(trail.missionId, parent.missionId);
    expect(trail.taskId, parent.taskId);
    expect(trail.sourceType, 'task_trail');
    expect(trail.trailType, TrailType.missionRecord);
    await tester.scrollUntilVisible(
      find.text('Task: パスポートの有効期限を確認する'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Task: パスポートの有効期限を確認する'), findsWidgets);
  });

  test('同じ作成IDの再送はTrailを重複させない', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(trailControllerProvider.notifier);

    for (var attempt = 0; attempt < 2; attempt++) {
      final saved = await controller.addManualTrailAndWait(
        trailId: 'stable-trail-id',
        title: '同じTrail',
        summary: '再送確認',
        content: '保存結果が不明でも同じIDで再試行する。',
        parent: parent,
      );
      expect(saved, isTrue);
    }

    expect(container.read(trailControllerProvider), hasLength(1));
    expect(
      container.read(trailControllerProvider).single.id,
      'stable-trail-id',
    );
  });

  test('Task Trail routeは階層と作成意図を欠落させない', () {
    final uri = Uri.parse(
      AppRoutes.trailForTask(
        questId: parent.questId,
        questTitle: parent.questTitle,
        missionId: parent.missionId!,
        missionTitle: parent.missionTitle!,
        taskId: parent.taskId!,
        taskTitle: parent.taskTitle!,
      ),
    );

    expect(uri.path, AppRoutes.trail);
    expect(uri.queryParameters['questId'], parent.questId);
    expect(uri.queryParameters['missionId'], parent.missionId);
    expect(uri.queryParameters['taskId'], parent.taskId);
    expect(uri.queryParameters['create'], '1');
  });

  test('TaskをMissionなしでTrailへ紐づける構造は拒否する', () {
    const invalid = TrailParentContext(
      questId: 'quest-1',
      questTitle: 'Quest',
      taskId: 'task-1',
      taskTitle: 'Task',
    );
    expect(invalid.isStructurallyValid, isFalse);
  });
}
