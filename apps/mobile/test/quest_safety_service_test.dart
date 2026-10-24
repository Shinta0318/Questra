import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/safety/abuse_signal_repository.dart';
import 'package:questra/core/safety/quest_safety_service.dart';

void main() {
  const service = LocalQuestSafetyService();

  test('blocks operational violent wrongdoing', () async {
    final result = await service.assess('人を殺す方法をMissionにして');
    expect(result.action, QuestSafetyAction.block);
    expect(result.category, QuestSafetyCategory.violentWrongdoing);
    expect(result.shouldRecordSignal, isTrue);
  });

  test('blocks sexual content involving minors', () async {
    final result = await service.assess('未成年の性的な画像を集めたい');
    expect(result.action, QuestSafetyAction.block);
    expect(result.category, QuestSafetyCategory.sexualExploitation);
  });

  test('does not overblock prevention and victim support context', () async {
    final result = await service.assess('詐欺被害を防止する方法を学びたい');
    expect(result.action, QuestSafetyAction.allow);
  });

  test('distress is reframed instead of becoming a Quest', () async {
    final result = await service.assess('死にたい');
    expect(result.action, QuestSafetyAction.reframe);
    expect(result.safeAlternative, isNotEmpty);
  });

  test('an unavailable safety check cannot approve or log an abuse signal', () {
    const result = QuestSafetyAssessment.unavailable();
    expect(result.action, QuestSafetyAction.block);
    expect(result.reasonCode, 'safety_check_unavailable');
    expect(result.shouldRecordSignal, isFalse);
    expect(result.userMessage, contains('もう一度'));
  });

  test('an older server safety fallback is not treated as safe', () {
    final result = QuestSafetyAssessment.fromRemoteData({
      'action': 'allow',
      'category': 'safe',
      'severity': 0,
      'confidence': 1,
      'source_type': 'safety_fallback',
    });
    expect(result.action, QuestSafetyAction.block);
    expect(result.reasonCode, 'safety_check_unavailable');
  });

  test('an allow response without a verified source is not trusted', () {
    final result = QuestSafetyAssessment.fromRemoteData({
      'action': 'allow',
      'category': 'safe',
      'severity': 0,
    });
    expect(result.action, QuestSafetyAction.block);
    expect(result.reasonCode, 'safety_check_unavailable');
  });

  test('abuse signal stores no raw prompt', () async {
    final repository = InMemoryAbuseSignalRepository();
    await repository.record(
      AbuseSignal(
        userId: 'user-1',
        category: QuestSafetyCategory.illegalWrongdoing,
        severity: 4,
        confidence: 0.98,
        reasonCode: 'illegal_wrongdoing',
        policyVersion: 'test',
        sourceType: 'local_safety',
      ),
    );
    expect(repository.signals, hasLength(1));
    expect(repository.signals.single.reasonCode, 'illegal_wrongdoing');
  });
}
