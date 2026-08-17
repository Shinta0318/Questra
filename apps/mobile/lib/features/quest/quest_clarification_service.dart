enum QuestClarificationType {
  deadline,
  budget,
  location,
  experience,
  safety,
  party,
  purpose,
  targetLevel,
  duration,
  frequency,
  travelActivity,
  travelStyle,
}

extension QuestClarificationTypeStorage on QuestClarificationType {
  String get storageKey => switch (this) {
    QuestClarificationType.targetLevel => 'target_level',
    QuestClarificationType.travelStyle => 'travel_style',
    QuestClarificationType.travelActivity => 'travel_activity',
    _ => name,
  };
}

QuestClarificationType? questClarificationTypeFromStorage(Object? value) {
  for (final type in QuestClarificationType.values) {
    if (type.storageKey == value) return type;
  }
  return null;
}

class QuestClarificationQuestion {
  const QuestClarificationQuestion({
    required this.type,
    required this.label,
    required this.hint,
  });

  final QuestClarificationType type;
  final String label;
  final String hint;

  static QuestClarificationQuestion? fromJson(Map value) {
    final item = Map<String, dynamic>.from(value);
    final type = questClarificationTypeFromStorage(item['type']);
    final label = (item['label'] as String?)?.trim() ?? '';
    if (type == null || label.isEmpty) return null;
    return QuestClarificationQuestion(
      type: type,
      label: label,
      hint: (item['hint'] as String?)?.trim() ?? '',
    );
  }
}

abstract final class QuestClarificationService {
  static const _questions =
      <QuestClarificationType, QuestClarificationQuestion>{
        QuestClarificationType.deadline: QuestClarificationQuestion(
          type: QuestClarificationType.deadline,
          label: 'いつ頃までに叶えたい？',
          hint: '決まっていなければ、未定のままでも大丈夫です。',
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
          hint: '例: 体調、食事、移動について',
        ),
        QuestClarificationType.party: QuestClarificationQuestion(
          type: QuestClarificationType.party,
          label: '誰と実現したい？',
          hint: '例: 一人で、家族と、友人と',
        ),
        QuestClarificationType.purpose: QuestClarificationQuestion(
          type: QuestClarificationType.purpose,
          label: 'その先で、どんな体験をしたい？',
          hint: '例: 現地の文化を楽しみたい、仕事で会話したい',
        ),
        QuestClarificationType.targetLevel: QuestClarificationQuestion(
          type: QuestClarificationType.targetLevel,
          label: 'どのくらいできる状態を目指したい？',
          hint: '例: 海外旅行で困らない、資格試験に合格する',
        ),
        QuestClarificationType.duration: QuestClarificationQuestion(
          type: QuestClarificationType.duration,
          label: 'どのくらいの期間、続けたい？',
          hint: '例: まず3か月、期限は決めずに続けたい',
        ),
        QuestClarificationType.frequency: QuestClarificationQuestion(
          type: QuestClarificationType.frequency,
          label: '無理なく続けられそうな頻度は？',
          hint: '例: 週3日、平日の朝20分',
        ),
        QuestClarificationType.travelStyle: QuestClarificationQuestion(
          type: QuestClarificationType.travelStyle,
          label: 'どんな旅行スタイルにしたい？',
          hint: '例: ゆったり、効率重視、ローカル体験中心、子ども優先',
        ),
        QuestClarificationType.travelActivity: QuestClarificationQuestion(
          type: QuestClarificationType.travelActivity,
          label: '旅で重視したいアクティビティや体験は？',
          hint: '例: 食文化、自然、買い物、テーマパーク、現地交流',
        ),
      };

  static List<QuestClarificationQuestion> resolve({
    required String input,
    required String category,
    required DateTime? targetDate,
    int maxQuestions = 5,
  }) {
    final source = '$category $input'.toLowerCase();
    final candidates = <QuestClarificationType>[];

    if (_isSpecificOutcome(source) && _hasDate(source)) {
      return const [];
    }

    if (_isTravel(input, source)) {
      if (targetDate == null && !_hasDate(source)) {
        candidates.add(QuestClarificationType.deadline);
      }
      if (!_hasParty(source)) {
        candidates.add(QuestClarificationType.party);
      }
      if (!_hasBudget(source)) {
        candidates.add(QuestClarificationType.budget);
      }
      if (!_hasTravelActivity(source)) {
        candidates.add(QuestClarificationType.travelActivity);
      }
      if (!_hasTravelStyle(source)) {
        candidates.add(QuestClarificationType.travelStyle);
      }
    } else if (_isLearning(source)) {
      if (!_hasPurpose(source)) candidates.add(QuestClarificationType.purpose);
      if (!_hasTargetLevel(source)) {
        candidates.add(QuestClarificationType.targetLevel);
      }
      if (!_hasExperience(source)) {
        candidates.add(QuestClarificationType.experience);
      }
    } else if (_isHabit(source)) {
      if (!_hasDuration(source)) {
        candidates.add(QuestClarificationType.duration);
      }
      if (!_hasFrequency(source)) {
        candidates.add(QuestClarificationType.frequency);
      }
    } else if (_isHealth(source)) {
      if (!_hasTargetLevel(source)) {
        candidates.add(QuestClarificationType.targetLevel);
      }
      if (!_hasExperience(source)) {
        candidates.add(QuestClarificationType.experience);
      }
      if (!_hasSafetyContext(source)) {
        candidates.add(QuestClarificationType.safety);
      }
    } else if (!_isSpecificOutcome(source)) {
      candidates.add(QuestClarificationType.purpose);
      if (targetDate == null && !_hasDate(source)) {
        candidates.add(QuestClarificationType.deadline);
      }
    }

    return candidates
        .toSet()
        .take(maxQuestions.clamp(0, 5))
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

  static DateTime? targetDateFromText(String source) {
    final slashDate = RegExp(
      r'(20\d{2})\s*[/.-]\s*(\d{1,2})(?:\s*[/.-]\s*(\d{1,2}))?',
    ).firstMatch(source);
    final japaneseDate = RegExp(
      r'(20\d{2})\s*年\s*(\d{1,2})\s*月(?:\s*(\d{1,2})\s*日)?',
    ).firstMatch(source);
    final match = slashDate ?? japaneseDate;
    if (match == null) return null;
    final year = int.tryParse(match.group(1) ?? '');
    final month = int.tryParse(match.group(2) ?? '');
    final day = int.tryParse(match.group(3) ?? '') ?? 1;
    if (year == null || month == null || month < 1 || month > 12) return null;
    final result = DateTime(year, month, day);
    if (result.year != year || result.month != month || result.day != day) {
      return null;
    }
    return result;
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

  static bool _isTravel(String input, String source) =>
      _containsAny(source, const ['旅行', '旅', '海外', '観光', '登山', 'キャンプ']) ||
      (_hasLocation(input) &&
          _containsAny(source, const ['行きたい', '行く', '訪れたい', '登りたい']));

  static bool _isLearning(String source) =>
      _containsAny(source, const ['学習', '勉強', '資格', '語学', '英語', '習得', '話せる']);

  static bool _isHabit(String source) =>
      _containsAny(source, const ['毎日', '毎朝', '毎週', '習慣', '継続']);

  static bool _isHealth(String source) =>
      _containsAny(source, const ['健康', '運動', '減量', 'マラソン', '筋トレ', '治療']);

  static bool _isSpecificOutcome(String source) =>
      _hasDate(source) ||
      RegExp(r'(\d+\s*(点|級|冊|回|km|kg|万円)|合格|完成|公開|取得)').hasMatch(source);

  static bool _hasDate(String source) =>
      targetDateFromText(source) != null ||
      RegExp(r'(20\d{2}\s*年|\d{1,2}\s*月|までに|来年|今年|今月)').hasMatch(source);

  static bool _hasLocation(String input) =>
      RegExp(
        r'[\p{L}\p{N}]{2,}(?:へ|に)(?:行|旅|訪|登)',
        unicode: true,
      ).hasMatch(input) ||
      _containsAny(input, const ['場所', '地域', 'オンライン', '自宅', '近所']);

  static bool _hasParty(String source) => _containsAny(source, const [
    '一人',
    'ひとり',
    '家族',
    '友人',
    '恋人',
    '夫婦',
    '仲間',
    '子ども',
  ]);

  static bool _hasPurpose(String source) => _containsAny(source, const [
    'ため',
    'ので',
    '仕事で',
    '旅行で',
    '文化',
    '体験',
    '将来',
    '目指',
  ]);

  static bool _hasBudget(String source) =>
      RegExp(r'(予算|費用|\d+\s*(円|万円)|無料|節約)').hasMatch(source);

  static bool _hasTravelStyle(String source) => _containsAny(source, const [
    'ゆったり',
    '効率',
    'ローカル',
    '高級',
    '節約',
    '子ども優先',
    '観光中心',
    '食事中心',
    'アクティブ',
  ]);

  static bool _hasTravelActivity(String source) => _containsAny(source, const [
    '文化',
    '食事',
    'グルメ',
    '自然',
    '買い物',
    'ショッピング',
    'テーマパーク',
    'アクティビティ',
    '現地交流',
    '観光',
  ]);

  static bool _hasTargetLevel(String source) =>
      RegExp(r'(\d+\s*(点|級|冊|回|km|kg)|合格|困らない|日常会話|完成)').hasMatch(source);

  static bool _hasExperience(String source) => _containsAny(source, const [
    '初めて',
    '初心者',
    '経験',
    '未経験',
    '準備済み',
    '取得済み',
    '勉強中',
  ]);

  static bool _hasDuration(String source) =>
      RegExp(r'(\d+\s*(日|週|か月|ヶ月|年)|しばらく|継続)').hasMatch(source);

  static bool _hasFrequency(String source) =>
      RegExp(r'(毎(日|朝|晩|週)|週\s*\d+\s*回|月\s*\d+\s*回)').hasMatch(source);

  static bool _hasSafetyContext(String source) =>
      _containsAny(source, const ['体調', '持病', 'アレルギー', '食事制限', '安全', '介助']);

  static bool _containsAny(String source, List<String> values) =>
      values.any(source.contains);

  static String _answerLabel(QuestClarificationType type) => switch (type) {
    QuestClarificationType.deadline => '期限',
    QuestClarificationType.budget => '予算',
    QuestClarificationType.location => '場所',
    QuestClarificationType.experience => '現在地',
    QuestClarificationType.safety => '配慮事項',
    QuestClarificationType.party => '同行者',
    QuestClarificationType.purpose => '実現したい体験',
    QuestClarificationType.targetLevel => '目指す状態',
    QuestClarificationType.duration => '継続期間',
    QuestClarificationType.frequency => '頻度',
    QuestClarificationType.travelStyle => '旅行スタイル',
    QuestClarificationType.travelActivity => '重視するアクティビティ・体験',
  };
}
