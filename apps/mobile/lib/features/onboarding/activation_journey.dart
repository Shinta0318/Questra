import '../auth/auth_state.dart';
import '../quest/quest_model.dart';
import '../task/task_load_state.dart';
import '../task/task_model.dart';

enum ActivationJourneyStage {
  trust,
  promise,
  wish,
  questConfirm,
  firstTask,
  complete,
}

class ActivationJourneySnapshot {
  const ActivationJourneySnapshot({
    required this.stage,
    required this.title,
    required this.message,
    required this.actionLabel,
    this.quest,
    this.task,
  });

  final ActivationJourneyStage stage;
  final String title;
  final String message;
  final String actionLabel;
  final Quest? quest;
  final QuestraTask? task;

  bool get isComplete => stage == ActivationJourneyStage.complete;
}

class ActivationJourneyService {
  const ActivationJourneyService();

  ActivationJourneySnapshot resolve({
    required UserProfile? profile,
    required List<Quest> quests,
    required List<QuestraTask> tasks,
    required TaskLoadState taskLoadState,
  }) {
    if (profile == null || !profile.legalAcceptanceCurrent) {
      return const ActivationJourneySnapshot(
        stage: ActivationJourneyStage.trust,
        title: '安心して始める準備',
        message: '個人の願いを扱う前に、保存と利用範囲を短く確認します。',
        actionLabel: '確認して始める',
      );
    }
    if (!profile.onboardingCompleted) {
      return const ActivationJourneySnapshot(
        stage: ActivationJourneyStage.promise,
        title: 'Questraでできること',
        message: 'Arcと一緒に願いをQuestへ変え、今日の一歩まで進めます。',
        actionLabel: 'はじまりを見る',
      );
    }

    final activeQuests = quests
        .where((quest) => quest.status == QuestStatus.active)
        .toList(growable: false);
    if (activeQuests.isEmpty) {
      return const ActivationJourneySnapshot(
        stage: ActivationJourneyStage.wish,
        title: '叶えたいことを一つ話す',
        message: 'まだ曖昧でも大丈夫です。Arcが短い質問で形にします。',
        actionLabel: 'Arcに話す',
      );
    }

    final startedTask = tasks.where((task) {
      return task.status == TaskStatus.inProgress ||
          task.status == TaskStatus.completed;
    }).firstOrNull;
    if (startedTask != null) {
      return ActivationJourneySnapshot(
        stage: ActivationJourneyStage.complete,
        title: '最初の一歩が始まりました',
        message: 'このTaskから、Questの航路が動き出しています。',
        actionLabel: '続きを見る',
        quest: _questForTask(activeQuests, startedTask),
        task: startedTask,
      );
    }

    final nextTask = tasks.where((task) => task.isOpen).firstOrNull;
    if (nextTask != null) {
      return ActivationJourneySnapshot(
        stage: ActivationJourneyStage.firstTask,
        title: '今日の一歩を始める',
        message: '最初は小さくて十分です。5分で動けるTaskから始めます。',
        actionLabel: 'Taskを始める',
        quest: _questForTask(activeQuests, nextTask),
        task: nextTask,
      );
    }

    final focusQuest = activeQuests.first;
    final waitingForTasks =
        taskLoadState.status == TaskLoadStatus.loading ||
        taskLoadState.status == TaskLoadStatus.idle;
    return ActivationJourneySnapshot(
      stage: ActivationJourneyStage.questConfirm,
      title: waitingForTasks ? '航路を準備中' : 'Questを確認する',
      message: waitingForTasks
          ? 'Arcが最初のTaskへつながる道筋を整えています。'
          : 'Questの目的を確認し、必要ならArcと最初のTaskを整えます。',
      actionLabel: waitingForTasks ? 'Questを見る' : 'Questを確認',
      quest: focusQuest,
    );
  }

  Quest? _questForTask(List<Quest> quests, QuestraTask task) {
    for (final quest in quests) {
      if (quest.id == task.questId) return quest;
    }
    return null;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
