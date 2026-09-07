import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/onboarding/activation_journey.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/task/task_load_state.dart';
import 'package:questra/features/task/task_model.dart';

void main() {
  const service = ActivationJourneyService();

  test('trust step is required before personal wish routing', () {
    final snapshot = service.resolve(
      profile: _profile(legalAcceptanceCurrent: false),
      quests: const [],
      tasks: const [],
      taskLoadState: const TaskLoadState(),
    );

    expect(snapshot.stage, ActivationJourneyStage.trust);
    expect(snapshot.title, '安心して始める準備');
    expect(snapshot.actionLabel, '確認して始める');
  });

  test('first-time user reaches wish input after trust and onboarding', () {
    final snapshot = service.resolve(
      profile: _profile(),
      quests: const [],
      tasks: const [],
      taskLoadState: const TaskLoadState(status: TaskLoadStatus.loaded),
    );

    expect(snapshot.stage, ActivationJourneyStage.wish);
    expect(snapshot.title, '叶えたいことを一つ話す');
    expect(snapshot.actionLabel, 'Arcに話す');
  });

  test('active Quest without Task asks the user to confirm the route', () {
    final quest = _quest();
    final snapshot = service.resolve(
      profile: _profile(),
      quests: [quest],
      tasks: const [],
      taskLoadState: const TaskLoadState(status: TaskLoadStatus.loaded),
    );

    expect(snapshot.stage, ActivationJourneyStage.questConfirm);
    expect(snapshot.quest?.id, quest.id);
    expect(snapshot.actionLabel, 'Questを確認');
  });

  test('open Task becomes the first action instead of another tutorial', () {
    final task = _task(status: TaskStatus.ready);
    final snapshot = service.resolve(
      profile: _profile(),
      quests: [_quest()],
      tasks: [task],
      taskLoadState: const TaskLoadState(status: TaskLoadStatus.loaded),
    );

    expect(snapshot.stage, ActivationJourneyStage.firstTask);
    expect(snapshot.task?.id, task.id);
    expect(snapshot.actionLabel, 'Taskを始める');
  });

  test('started Task completes the activation contract', () {
    final task = _task(status: TaskStatus.inProgress);
    final snapshot = service.resolve(
      profile: _profile(),
      quests: [_quest()],
      tasks: [task],
      taskLoadState: const TaskLoadState(status: TaskLoadStatus.loaded),
    );

    expect(snapshot.stage, ActivationJourneyStage.complete);
    expect(snapshot.isComplete, isTrue);
  });
}

UserProfile _profile({
  bool onboardingCompleted = true,
  bool legalAcceptanceCurrent = true,
}) => UserProfile(
  id: 'user-1',
  email: 'user@example.com',
  nickname: '旅人',
  onboardingCompleted: onboardingCompleted,
  legalAcceptanceCurrent: legalAcceptanceCurrent,
);

Quest _quest() => Quest(
  id: 'quest-1',
  title: 'シンガポール旅行を実現する',
  description: '家族で行きたい場所を具体化する',
  difficulty: QuestDifficulty.normal,
  status: QuestStatus.active,
  visibility: QuestVisibility.private,
);

QuestraTask _task({required TaskStatus status}) => QuestraTask(
  id: 'task-1',
  questId: 'quest-1',
  missionId: 'mission-1',
  questTitle: 'シンガポール旅行を実現する',
  missionTitle: '旅行条件を決める',
  title: '旅行時期を決める',
  action: '同行者と予定を確認し、旅行できる月を一つ決める',
  doneCondition: '旅行できる年月が決まっている',
  status: status,
);
