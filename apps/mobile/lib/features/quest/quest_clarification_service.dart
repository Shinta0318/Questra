enum QuestClarificationType { deadline, budget, location, experience, safety }

class QuestClarificationQuestion {
  const QuestClarificationQuestion({
    required this.type,
    required this.label,
    required this.hint,
  });

  final QuestClarificationType type;
  final String label;
  final String hint;
}

abstract final class QuestClarificationService {
  static const _questions =
      <QuestClarificationType, QuestClarificationQuestion>{
        QuestClarificationType.deadline: QuestClarificationQuestion(
          type: QuestClarificationType.deadline,
          label: 'いつまでに叶えたい？',
          hint: '未定でも、そのまま進められます。',
        ),
        QuestClarificationType.budget: QuestClarificationQuestion(
          type: QuestClarificationType.budget,
          label: '使える予算の目安は？',
          hint: '例: 20万円まで、まずは無料で試したい',
        ),
        QuestClarificationType.location: QuestClarificationQuestion(
          type: QuestClarificationType.location,
          label: '場所や地域の希望は？',
          hint: '例: シンガポール、市内から通える範囲',
        ),
        QuestClarificationType.experience: QuestClarificationQuestion(
          type: QuestClarificationType.experience,
          label: '今の経験や準備状況は？',
          hint: '例: 初めて、基礎は学習済み、旅券は取得済み',
        ),
        QuestClarificationType.safety: QuestClarificationQuestion(
          type: QuestClarificationType.safety,
          label: '配慮したいことは？',
          hint: '例: 体調、食事、移動、同行者について',
        ),
      };

  static List<QuestClarificationQuestion> resolve({
    required String input,
    required String category,
    required DateTime? targetDate,
    int maxQuestions = 3,
  }) {
    final source = '$category $input'.toLowerCase();
    final candidates = <QuestClarificationType>[];

    if (targetDate == null) candidates.add(QuestClarificationType.deadline);

    if (_isTravel(input, source)) {
      if (!_hasBudget(source)) candidates.add(QuestClarificationType.budget);
      if (!_hasLocation(input)) candidates.add(QuestClarificationType.location);
      if (!_hasExperience(source)) {
        candidates.add(QuestClarificationType.experience);
      }
      if (!_hasSafetyContext(source)) {
        candidates.add(QuestClarificationType.safety);
      }
    } else if (_containsAny(source, const [
      '学習',
      '勉強',
      '資格',
      '語学',
      '英語',
      '習得',
    ])) {
      if (!_hasExperience(source)) {
        candidates.add(QuestClarificationType.experience);
      }
      if (!_hasBudget(source)) candidates.add(QuestClarificationType.budget);
    } else if (_containsAny(source, const [
      '健康',
      '運動',
      '減量',
      'マラソン',
      '筋トレ',
      '治療',
    ])) {
      if (!_hasExperience(source)) {
        candidates.add(QuestClarificationType.experience);
      }
      if (!_hasSafetyContext(source)) {
        candidates.add(QuestClarificationType.safety);
      }
    } else if (_containsAny(source, const [
      '起業',
      '仕事',
      '転職',
      '副業',
      '開発',
      '制作',
    ])) {
      if (!_hasBudget(source)) candidates.add(QuestClarificationType.budget);
      if (!_hasExperience(source)) {
        candidates.add(QuestClarificationType.experience);
      }
    } else if (!_hasExperience(source)) {
      candidates.add(QuestClarificationType.experience);
    }

    return candidates
        .toSet()
        .take(maxQuestions.clamp(0, 3))
        .map((type) => _questions[type]!)
        .toList(growable: false);
  }

  static String appendAnsweredContext({
    required String description,
    required DateTime? targetDate,
    required Map<QuestClarificationType, String> answers,
  }) {
    final lines = answerLines(targetDate: targetDate, answers: answers);
    if (lines.isEmpty) return description.trim();
    return '${description.trim()}\n\n航路条件:\n${lines.map((line) => '- $line').join('\n')}';
  }

  static List<String> answerLines({
    required DateTime? targetDate,
    required Map<QuestClarificationType, String> answers,
  }) {
    final lines = <String>[];
    if (targetDate != null) {
      lines.add(
        '期限: ${targetDate.year}年${targetDate.month}月${targetDate.day}日',
      );
    }
    for (final type in QuestClarificationType.values) {
      if (type == QuestClarificationType.deadline) continue;
      final value = answers[type]?.trim() ?? '';
      if (value.isEmpty) continue;
      lines.add('${_answerLabel(type)}: $value');
    }
    return lines;
  }

  static bool _hasBudget(String source) =>
      RegExp(r'(予算|費用|無料|\d[\d,.]*\s*(円|万円|ドル))').hasMatch(source);

  static bool _isTravel(String input, String source) =>
      _containsAny(source, const ['旅行', '旅', '海外', '観光', '登山', 'キャンプ']) ||
      (_hasLocation(input) &&
          _containsAny(source, const ['行きたい', '行く', '訪れたい', '登りたい']));

  static bool _hasLocation(String input) =>
      RegExp(
        r'[\p{L}\p{N}]{2,}(?:へ|に)(?:行|旅|訪|登)',
        unicode: true,
      ).hasMatch(input) ||
      _containsAny(input, const ['場所', '地域', 'オンライン', '自宅', '近所']);

  static bool _hasExperience(String source) => _containsAny(source, const [
    '初めて',
    '初心者',
    '経験',
    '未経験',
    '準備済み',
    '取得済み',
    '勉強中',
  ]);

  static bool _hasSafetyContext(String source) => _containsAny(source, const [
    '体調',
    '持病',
    'アレルギー',
    '食事制限',
    '安全',
    '同行',
    '子ども',
    '介助',
  ]);

  static bool _containsAny(String source, List<String> values) =>
      values.any(source.contains);

  static String _answerLabel(QuestClarificationType type) => switch (type) {
    QuestClarificationType.deadline => '期限',
    QuestClarificationType.budget => '予算',
    QuestClarificationType.location => '場所',
    QuestClarificationType.experience => '現在地',
    QuestClarificationType.safety => '配慮事項',
  };
}
