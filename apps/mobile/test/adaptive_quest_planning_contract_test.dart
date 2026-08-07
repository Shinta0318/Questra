import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fallback planning does not derive Mission wording from templates', () {
    final root = Directory.current.parent.parent;
    final guide = File(
      '${root.path}/supabase/functions/arc-quest-guide/index.ts',
    ).readAsStringSync();

    expect(guide, contains('from the Quest\'s success condition'));
    expect(guide, contains('quality_viewpoint'));
    expect(guide, isNot(contains('template.steps.map((item, index)')));
    expect(guide, contains('reviewMissionCandidates'));
    expect(guide, contains('abstractOnly'));
    expect(guide, contains('critiqueAndRepairGuide'));
    expect(guide, contains('quest_guide_critic_v1'));
    expect(guide, contains('critic_passes: 1'));
  });
}
