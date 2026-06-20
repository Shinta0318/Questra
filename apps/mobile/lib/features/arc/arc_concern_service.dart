import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/arc/arc_emotion.dart';
import '../mission/mission_model.dart';
import '../quest/quest_model.dart';
import '../trail/trail_model.dart';

final arcConcernServiceProvider = Provider<ArcConcernService>(
  (ref) => const ArcConcernService(),
);

enum ArcConcernType { overdueQuest, staleMission, lowActivity }

class ArcConcern {
  const ArcConcern({
    required this.type,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.emotion,
    this.questId,
    this.missionId,
  });

  final ArcConcernType type;
  final String title;
  final String message;
  final String actionLabel;
  final ArcEmotion emotion;
  final String? questId;
  final String? missionId;
}

class ArcConcernService {
  const ArcConcernService();

  ArcConcern? evaluate({
    required List<Quest> quests,
    required List<Mission> missions,
    required List<Trail> trails,
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final activeQuests =
        quests.where((quest) => quest.status == QuestStatus.active).toList()
          ..sort(
            (a, b) => (a.targetDate ?? today).compareTo(b.targetDate ?? today),
          );
    final openMissions =
        missions
            .where((mission) => mission.status == MissionStatus.todo)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final recentTrails = [...trails]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final overdueQuest = activeQuests.where((quest) {
      final targetDate = quest.targetDate;
      return targetDate != null &&
          _dateOnly(targetDate).isBefore(today) &&
          quest.progress < 1;
    }).firstOrNull;
    if (overdueQuest != null) {
      return ArcConcern(
        type: ArcConcernType.overdueQuest,
        questId: overdueQuest.id,
        title: 'Questの予定日を過ぎています',
        message:
            '「${overdueQuest.title}」の星が少し遠ざかっています。責める必要はありません。今日できる10分のMissionへ小さく戻りましょう。',
        actionLabel: 'Questを見直す',
        emotion: ArcEmotion.worried,
      );
    }

    final staleMission = openMissions.where((mission) {
      return today.difference(_dateOnly(mission.createdAt)).inDays >= 3;
    }).firstOrNull;
    if (staleMission != null) {
      return ArcConcern(
        type: ArcConcernType.staleMission,
        questId: staleMission.questId,
        missionId: staleMission.id,
        title: '止まっているMissionがあります',
        message:
            '「${staleMission.title}」は少し長く港に停泊しています。完了を急がず、半分の大きさに分けるところから始めましょう。',
        actionLabel: 'Missionを確認',
        emotion: ArcEmotion.worried,
      );
    }

    final hasRecentTrail =
        recentTrails.isNotEmpty &&
        today.difference(_dateOnly(recentTrails.first.createdAt)).inDays <= 7;
    if (activeQuests.isNotEmpty && !hasRecentTrail) {
      return ArcConcern(
        type: ArcConcernType.lowActivity,
        questId: activeQuests.first.id,
        title: '最近のTrailが静かです',
        message: '航路が静かな日もあります。今は大きく進めるより、気づきか迷いをTrailに一行だけ残すのがよさそうです。',
        actionLabel: 'Trailを残す',
        emotion: ArcEmotion.support,
      );
    }

    return null;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
