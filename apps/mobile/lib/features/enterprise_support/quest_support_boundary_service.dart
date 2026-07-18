import '../quest/quest_model.dart';

enum QuestSupportRole { sponsor, coach, partner, officialEventHost }

class QuestSupportBoundary {
  const QuestSupportBoundary({
    required this.isActive,
    required this.statusLabel,
    required this.summary,
    required this.roles,
    required this.transparencyChecklist,
    required this.guardrails,
  });

  final bool isActive;
  final String statusLabel;
  final String summary;
  final List<QuestSupportRole> roles;
  final List<String> transparencyChecklist;
  final List<String> guardrails;
}

class QuestSupportBoundaryService {
  const QuestSupportBoundaryService();

  QuestSupportBoundary resolve({required Quest quest}) {
    return QuestSupportBoundary(
      isActive: false,
      statusLabel: 'Betaでは未接続',
      summary: '${quest.title}に企業支援を表示する場合も、広告ではなくQuest前進の支援として透明に扱います。',
      roles: const [
        QuestSupportRole.sponsor,
        QuestSupportRole.coach,
        QuestSupportRole.partner,
        QuestSupportRole.officialEventHost,
      ],
      transparencyChecklist: const [
        '支援者',
        '支援内容',
        '選定理由',
        '費用または特典',
        'スポンサー関係',
        '非表示とフィードバック',
      ],
      guardrails: const [
        'Arcの信頼を販売しない',
        'Quest作成を広告導線にしない',
        '本人の同意なく個別データを利用しない',
      ],
    );
  }
}

extension QuestSupportRoleLabel on QuestSupportRole {
  String get label {
    return switch (this) {
      QuestSupportRole.sponsor => 'Sponsor',
      QuestSupportRole.coach => 'Coach',
      QuestSupportRole.partner => 'Partner',
      QuestSupportRole.officialEventHost => 'Official Event Host',
    };
  }

  String get description {
    return switch (this) {
      QuestSupportRole.sponsor => '特典や費用支援',
      QuestSupportRole.coach => '専門知識や学習支援',
      QuestSupportRole.partner => '道具やサービス支援',
      QuestSupportRole.officialEventHost => '公式イベントや安全な参加機会',
    };
  }
}
