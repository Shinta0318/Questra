import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/task/task_model.dart';
import 'package:questra/features/task/task_repository.dart';

void main() {
  test('versioned Task update rejects stale content', () async {
    final repository = InMemoryTaskRepository();
    final original = QuestraTask(
      questId: 'quest',
      questTitle: '富士山に登る',
      missionId: 'mission',
      missionTitle: '登山準備',
      title: '装備を調べる',
      action: '公式情報を確認する',
      doneCondition: '装備一覧を記録する',
    );
    await repository.save(original);
    final updated = await repository.updateWithVersion(
      original.copyWith(title: '装備を選ぶ'),
      operationId: 'edit-1',
    );
    expect(updated.version, original.version + 1);
    await expectLater(
      repository.updateWithVersion(
        original.copyWith(title: '古い画面の変更'),
        operationId: 'edit-2',
      ),
      throwsA(isA<TaskVersionConflictException>()),
    );
    final saved = await repository.findByMission('mission');
    expect(saved.single.title, '装備を選ぶ');
  });
}
