import 'quest_model.dart';
import 'quest_theme_card.dart';

enum QuestDnaSource { userInput, inferred }

class QuestDnaAttribute {
  const QuestDnaAttribute({
    required this.key,
    required this.label,
    required this.value,
    required this.source,
  });

  final String key;
  final String label;
  final String value;
  final QuestDnaSource source;
}

class QuestDnaSnapshot {
  const QuestDnaSnapshot({required this.attributes});

  final List<QuestDnaAttribute> attributes;
}

class QuestDnaSnapshotResolver {
  const QuestDnaSnapshotResolver();

  QuestDnaSnapshot resolve(Quest quest) {
    final theme = const QuestThemeResolver().resolve(quest);

    return QuestDnaSnapshot(
      attributes: [
        QuestDnaAttribute(
          key: 'category',
          label: 'カテゴリ',
          value: quest.category,
          source: QuestDnaSource.userInput,
        ),
        QuestDnaAttribute(
          key: 'theme',
          label: 'テーマ',
          value: theme.name,
          source: QuestDnaSource.inferred,
        ),
        QuestDnaAttribute(
          key: 'difficulty',
          label: '難易度',
          value: quest.difficulty.label,
          source: QuestDnaSource.userInput,
        ),
        QuestDnaAttribute(
          key: 'duration',
          label: '期間',
          value: _durationLabel(quest),
          source: QuestDnaSource.inferred,
        ),
        QuestDnaAttribute(
          key: 'motivation_type',
          label: '動機',
          value: _motivationLabel(quest, theme),
          source: QuestDnaSource.inferred,
        ),
        QuestDnaAttribute(
          key: 'social_type',
          label: '共有範囲',
          value: _socialLabel(quest),
          source: QuestDnaSource.inferred,
        ),
        QuestDnaAttribute(
          key: 'risk_level',
          label: '注意度',
          value: _riskLabel(quest),
          source: QuestDnaSource.inferred,
        ),
      ],
    );
  }

  String _durationLabel(Quest quest) {
    final targetDate = quest.targetDate;
    if (targetDate == null) {
      return '未設定';
    }

    final days = targetDate.difference(DateTime.now()).inDays;
    if (days <= 0) {
      return '期限到来';
    }
    if (days <= 30) {
      return '短期';
    }
    if (days <= 180) {
      return '中期';
    }
    return '長期';
  }

  String _motivationLabel(Quest quest, QuestThemeCard theme) {
    final source = '${quest.category} ${quest.title} ${quest.description}'
        .toLowerCase();
    if (source.contains('学') || theme.name == '学びの航海') {
      return '学習';
    }
    if (source.contains('家族') || theme.name == 'あたたかな港') {
      return '関係';
    }
    if (source.contains('仕事') || source.contains('起業')) {
      return '達成';
    }
    if (quest.difficulty == QuestDifficulty.legendary ||
        source.contains('挑戦')) {
      return '挑戦';
    }
    return '成長';
  }

  String _socialLabel(Quest quest) {
    return switch (quest.visibility) {
      QuestVisibility.private => '個人',
      QuestVisibility.guild => 'Guild',
      QuestVisibility.public => '公開',
    };
  }

  String _riskLabel(Quest quest) {
    final source = '${quest.category} ${quest.title} ${quest.description}'
        .toLowerCase();
    if (source.contains('山') ||
        source.contains('登') ||
        source.contains('投資') ||
        source.contains('お金')) {
      return '注意';
    }
    return switch (quest.difficulty) {
      QuestDifficulty.easy => '低',
      QuestDifficulty.normal => '中',
      QuestDifficulty.hard => '中',
      QuestDifficulty.legendary => '高',
    };
  }
}
