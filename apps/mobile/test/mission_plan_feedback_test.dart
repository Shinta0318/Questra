import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_plan_feedback.dart';

void main() {
  test('feedback payload contains no raw prompt or message', () {
    const feedback = MissionPlanFeedback(
      questId: 'q',
      missionId: 'm',
      reason: MissionPlanFeedbackReason.tooAbstract,
      generationVersion: 'v3',
    );
    final data = feedback.toInsert('owner');
    expect(data['reason'], 'tooAbstract');
    expect(data.containsKey('message'), isFalse);
    expect(data.containsKey('prompt'), isFalse);
  });
}
