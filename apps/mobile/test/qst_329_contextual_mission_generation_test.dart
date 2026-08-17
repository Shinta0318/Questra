import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Gemini planning rejects internal planning artifacts', () {
    final prompts = File(
      '../../supabase/functions/_shared/quest_planning/prompt_registry.ts',
    ).readAsStringSync();
    final validators = File(
      '../../supabase/functions/_shared/quest_planning/validators.ts',
    ).readAsStringSync();

    expect(prompts, contains('explicit clarification answers'));
    expect(prompts, contains('schedule, companions, budget'));
    expect(prompts, contains('internal planning artifacts'));
    expect(validators, contains('internal_planning_artifact'));
    expect(validators, contains('達成したと分かる状態を決める'));
    expect(validators, contains('今の条件と不明点を分ける'));
  });

  test('local fallback cannot expose fixed Mission candidates', () {
    final service = File(
      'lib/features/quest/arc_quest_guide_service.dart',
    ).readAsStringSync();

    expect(service, contains('Gemini Planning APIを利用できません。入力内容は保持されています。'));
    expect(service, isNot(contains('_adaptiveFallbackCandidates')));
    expect(service, isNot(contains('_missionCandidates')));
    expect(service, isNot(contains('_complexFallback')));
    expect(service, isNot(contains('local_arc_quest_guide')));
  });
}
