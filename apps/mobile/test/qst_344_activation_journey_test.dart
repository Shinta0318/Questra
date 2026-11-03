import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/onboarding/activation_journey.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
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

  test('Task from an archived Quest does not complete or drive activation', () {
    final snapshot = service.resolve(
      profile: _profile(),
      quests: [
        _quest(),
        _quest(id: 'old-quest', status: QuestStatus.archived),
      ],
      tasks: [
        _task(
          id: 'old-task',
          questId: 'old-quest',
          status: TaskStatus.completed,
        ),
        _task(status: TaskStatus.ready),
      ],
      taskLoadState: const TaskLoadState(status: TaskLoadStatus.loaded),
    );

    expect(snapshot.stage, ActivationJourneyStage.firstTask);
    expect(snapshot.quest?.id, 'quest-1');
    expect(snapshot.task?.id, 'task-1');
  });

  test('an archived ready Task is not the first Task of an active Quest', () {
    final snapshot = service.resolve(
      profile: _profile(),
      quests: [
        _quest(),
        _quest(id: 'old-quest', status: QuestStatus.archived),
      ],
      tasks: [
        _task(id: 'old-task', questId: 'old-quest', status: TaskStatus.ready),
        _task(status: TaskStatus.ready),
      ],
      taskLoadState: const TaskLoadState(status: TaskLoadStatus.loaded),
    );

    expect(snapshot.stage, ActivationJourneyStage.firstTask);
    expect(snapshot.task?.id, 'task-1');
  });

  test('deferred, blocked, and dependent Tasks are not offered as ready', () {
    final snapshot = service.resolve(
      profile: _profile(),
      quests: [_quest()],
      tasks: [
        _task(id: 'later', status: TaskStatus.deferred),
        _task(id: 'blocked', status: TaskStatus.blocked),
        _task(
          id: 'dependent',
          status: TaskStatus.ready,
          dependencyIds: const ['first'],
        ),
        _task(id: 'first', status: TaskStatus.ready),
      ],
      taskLoadState: const TaskLoadState(status: TaskLoadStatus.loaded),
    );

    expect(snapshot.stage, ActivationJourneyStage.firstTask);
    expect(snapshot.task?.id, 'first');
  });

  test('only unavailable Tasks return to Quest confirmation', () {
    final snapshot = service.resolve(
      profile: _profile(),
      quests: [_quest()],
      tasks: [_task(status: TaskStatus.blocked)],
      taskLoadState: const TaskLoadState(status: TaskLoadStatus.loaded),
    );

    expect(snapshot.stage, ActivationJourneyStage.questConfirm);
    expect(snapshot.task, isNull);
  });

  test('a Task in a paused Mission cannot complete or drive activation', () {
    final snapshot = service.resolve(
      profile: _profile(),
      quests: [_quest()],
      tasks: [_task(status: TaskStatus.completed)],
      missions: [
        Mission(
          id: 'mission-1',
          questId: 'quest-1',
          questTitle: 'シンガポール旅行を実現する',
          title: '旅行条件を決める',
          description: '旅行条件',
          guideType: GuideType.route,
          difficulty: MissionDifficulty.normal,
          status: MissionStatus.todo,
          routeState: MissionRouteState.paused,
        ),
      ],
      taskLoadState: const TaskLoadState(status: TaskLoadStatus.loaded),
    );

    expect(snapshot.stage, ActivationJourneyStage.questConfirm);
    expect(snapshot.task, isNull);
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

Quest _quest({
  String id = 'quest-1',
  QuestStatus status = QuestStatus.active,
}) => Quest(
  id: id,
  title: 'シンガポール旅行を実現する',
  description: '家族で行きたい場所を具体化する',
  difficulty: QuestDifficulty.normal,
  status: status,
  visibility: QuestVisibility.private,
);

QuestraTask _task({
  String id = 'task-1',
  String questId = 'quest-1',
  required TaskStatus status,
  List<String> dependencyIds = const [],
}) => QuestraTask(
  id: id,
  questId: questId,
  missionId: 'mission-1',
  questTitle: 'シンガポール旅行を実現する',
  missionTitle: '旅行条件を決める',
  title: '旅行時期を決める',
  action: '同行者と予定を確認し、旅行できる月を一つ決める',
  doneCondition: '旅行できる年月が決まっている',
  status: status,
  dependencyIds: dependencyIds,
);
