import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/enterprise_support/quest_support_boundary_service.dart';
import 'package:questra/features/quest/quest_model.dart';

void main() {
  const service = QuestSupportBoundaryService();

  test('keeps enterprise support inactive and transparent for Beta', () {
    final boundary = service.resolve(
      quest: Quest(
        title: '富士山に登る',
        description: '安全に登頂する',
        difficulty: QuestDifficulty.hard,
        status: QuestStatus.active,
        visibility: QuestVisibility.private,
        category: '挑戦',
      ),
    );

    expect(boundary.isActive, isFalse);
    expect(boundary.statusLabel, 'Betaでは未接続');
    expect(boundary.roles, contains(QuestSupportRole.sponsor));
    expect(boundary.roles, contains(QuestSupportRole.coach));
    expect(boundary.roles, contains(QuestSupportRole.partner));
    expect(boundary.roles, contains(QuestSupportRole.officialEventHost));
    expect(boundary.transparencyChecklist, contains('スポンサー関係'));
    expect(boundary.guardrails, contains('Arcの信頼を販売しない'));
  });
}
