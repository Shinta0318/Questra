import 'package:flutter/material.dart';

import '../../core/theme/questra_colors.dart';
import 'quest_model.dart';

class QuestThemeCard {
  const QuestThemeCard({
    required this.name,
    required this.icon,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.dnaLabel,
    required this.arcHint,
  });

  final String name;
  final IconData icon;
  final Color primary;
  final Color secondary;
  final Color accent;
  final String dnaLabel;
  final String arcHint;

  LinearGradient get backgroundGradient => LinearGradient(
    colors: [
      primary,
      secondary.withValues(alpha: 0.92),
      QuestraColors.deepNavy,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  LinearGradient get posterGradient => LinearGradient(
    colors: [accent.withValues(alpha: 0.92), secondary.withValues(alpha: 0.62)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class QuestThemeResolver {
  const QuestThemeResolver();

  QuestThemeCard resolve(Quest quest) {
    final source = '${quest.category} ${quest.title} ${quest.description}'
        .toLowerCase();

    if (_containsAny(source, const ['学習', '英語', 'study', 'learn', '資格'])) {
      return const QuestThemeCard(
        name: '学びの航海',
        icon: Icons.menu_book_outlined,
        primary: QuestraColors.midnightNavy,
        secondary: Color(0xFF284FA8),
        accent: Color(0xFF8FD3FF),
        dnaLabel: '学習 / スキル',
        arcHint: '知識の星を少しずつ結んでいこう。',
      );
    }
    if (_containsAny(source, const ['健康', '運動', 'fitness', 'run', '登る', '山'])) {
      return const QuestThemeCard(
        name: '挑戦の地平線',
        icon: Icons.directions_run_outlined,
        primary: Color(0xFF0A2A32),
        secondary: Color(0xFF157A6E),
        accent: Color(0xFF69F0AE),
        dnaLabel: '健康 / 挑戦',
        arcHint: '身体が覚える一歩も、立派なTrailになるよ。',
      );
    }
    if (_containsAny(source, const ['仕事', '起業', 'business', 'launch', '開発'])) {
      return const QuestThemeCard(
        name: '創造の航路',
        icon: Icons.rocket_launch_outlined,
        primary: QuestraColors.midnightNavy,
        secondary: Color(0xFF334155),
        accent: QuestraColors.gold,
        dnaLabel: '仕事 / 創造',
        arcHint: '構想をMissionに分ければ、航路は見えてくる。',
      );
    }
    if (_containsAny(source, const ['家族', 'family', '暮らし', '生活'])) {
      return const QuestThemeCard(
        name: 'あたたかな港',
        icon: Icons.favorite_border,
        primary: Color(0xFF2A1836),
        secondary: Color(0xFF9A4D6C),
        accent: Color(0xFFFFC7A8),
        dnaLabel: '家族 / 暮らし',
        arcHint: '大切な人との時間も、君の星図の中心だよ。',
      );
    }
    if (_containsAny(source, const [
      '旅',
      '旅行',
      'travel',
      '富士',
      '冒険',
      'adventure',
    ])) {
      return const QuestThemeCard(
        name: '冒険の星図',
        icon: Icons.travel_explore,
        primary: QuestraColors.midnightNavy,
        secondary: QuestraColors.cosmicBlue,
        accent: QuestraColors.gold,
        dnaLabel: '冒険 / 旅',
        arcHint: '遠い目的地も、今日の一歩から近づいていく。',
      );
    }

    return const QuestThemeCard(
      name: '自分だけのQuest',
      icon: Icons.auto_awesome_outlined,
      primary: QuestraColors.midnightNavy,
      secondary: QuestraColors.cosmicBlue,
      accent: QuestraColors.gold,
      dnaLabel: 'Quest DNA',
      arcHint: 'まだ名前のない願いも、ここから形にしていこう。',
    );
  }

  bool _containsAny(String source, List<String> keywords) {
    return keywords.any(source.contains);
  }
}
