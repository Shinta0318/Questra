import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/arc/arc_emotion.dart';
import '../auth/auth_state.dart';
import '../mission/mission_model.dart';
import '../quest/quest_model.dart';
import '../trail/trail_model.dart';

final arcDailyGreetingServiceProvider = Provider<ArcDailyGreetingService>(
  (ref) => const ArcDailyGreetingService(),
);

class ArcDailyGreeting {
  const ArcDailyGreeting({
    required this.message,
    required this.contextLabel,
    required this.emotion,
  });

  final String message;
  final String contextLabel;
  final ArcEmotion emotion;
}

class ArcDailyGreetingService {
  const ArcDailyGreetingService();

  ArcDailyGreeting resolve({
    required List<Quest> quests,
    required List<Mission> missions,
    required List<Trail> trails,
    required DateTime now,
    String? nickname,
    String? arcName,
    QuestInterest questInterest = QuestInterest.adventure,
  }) {
    final name = _displayName(nickname);
    final guideName = _displayArcName(arcName);
    final today = _dateOnly(now);
    final activeQuests =
        quests.where((quest) => quest.status == QuestStatus.active).toList()
          ..sort((a, b) => b.progress.compareTo(a.progress));
    final openMissions =
        missions
            .where((mission) => mission.status == MissionStatus.todo)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recentTrails = [...trails]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final latestTrail = recentTrails.firstOrNull;
    if (latestTrail != null &&
        today.difference(_dateOnly(latestTrail.createdAt)).inDays <= 1) {
      return ArcDailyGreeting(
        message:
            'おかえり、$name。\nTrail「${latestTrail.title}」の星がまだ温かく残っています。次の一歩を小さく選びましょう。',
        contextLabel: '${_weekdayLabel(now)}のTrail',
        emotion: ArcEmotion.celebrate,
      );
    }

    final openMission = openMissions.firstOrNull;
    if (openMission != null) {
      final ageInDays = today
          .difference(_dateOnly(openMission.createdAt))
          .inDays;
      final isStale = ageInDays >= 3;
      return ArcDailyGreeting(
        message: isStale
            ? 'おかえり、$name。\nMission「${openMission.title}」が少し長く港にいます。今日は半分の大きさにして、航路へ戻りましょう。'
            : 'おかえり、$name。\n今日のMissionは「${openMission.title}」。完璧より、記録できる一歩を一緒に選びましょう。',
        contextLabel: isStale ? '見直しのMission' : '今日のMission',
        emotion: isStale ? ArcEmotion.worried : ArcEmotion.support,
      );
    }

    final activeQuest = activeQuests.firstOrNull;
    if (activeQuest != null) {
      final progressPercent = (activeQuest.progress * 100).round();
      return ArcDailyGreeting(
        message:
            'おかえり、$name。\n「${activeQuest.title}」は$progressPercent%まで進んでいます。今日はTrailに残せる小さな航跡を作りましょう。',
        contextLabel: '進行中のQuest',
        emotion: ArcEmotion.normal,
      );
    }

    if (trails.isEmpty && quests.isEmpty) {
      return ArcDailyGreeting(
        message:
            '${_timeGreeting(now)}、$name。\n$guideNameは${questInterest.label}の星を見ています。最初のQuestをひとつ置けば、そこから航路を一緒に描けます。',
        contextLabel: '${questInterest.label}の最初の航路',
        emotion: ArcEmotion.excited,
      );
    }

    return ArcDailyGreeting(
      message:
          '${_timeGreeting(now)}、$name。\n${_weekdayLabel(now)}の空は静かです。今日は気づきを一行だけTrailに残すのがよさそうです。',
      contextLabel: '日次ナビゲーション',
      emotion: ArcEmotion.support,
    );
  }

  String _displayName(String? nickname) {
    final trimmed = nickname?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'キャプテン';
    }
    return trimmed;
  }

  String _displayArcName(String? arcName) {
    final trimmed = arcName?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'Arc';
    }
    return trimmed;
  }

  String _timeGreeting(DateTime now) {
    if (now.hour < 11) {
      return 'おはよう';
    }
    if (now.hour < 17) {
      return 'こんにちは';
    }
    return 'こんばんは';
  }

  String _weekdayLabel(DateTime now) {
    return switch (now.weekday) {
      DateTime.monday => '月曜日',
      DateTime.tuesday => '火曜日',
      DateTime.wednesday => '水曜日',
      DateTime.thursday => '木曜日',
      DateTime.friday => '金曜日',
      DateTime.saturday => '土曜日',
      DateTime.sunday => '日曜日',
      _ => '今日',
    };
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
