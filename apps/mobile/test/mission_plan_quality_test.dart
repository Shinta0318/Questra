import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/mission_plan_quality.dart';

void main() {
  test('plan quality round trip keeps bounded release metadata', () {
    final quality = MissionPlanQuality.fromJson({
      'score': 0.91,
      'generation_version': 'quest_guide_v3',
      'critic_passes': 1,
      'repaired_mission_count': 2,
      'generated_at': '2026-08-01T00:00:00Z',
    });

    expect(quality, isNotNull);
    expect(quality!.score, 0.91);
    expect(quality.criticPasses, 1);
    expect(quality.toJson()['repaired_mission_count'], 2);
  });

  test('plan quality rejects incomplete metadata', () {
    expect(MissionPlanQuality.fromJson({'score': 0.8}), isNull);
  });
}
