import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = _repoRoot();
  String read(String path) => File('${root.path}/$path').readAsStringSync();

  test(
    'reachable legacy planning endpoints never return fixed Mission bodies',
    () {
      final guide = read('supabase/functions/arc-quest-guide/index.ts');
      final mission = read('supabase/functions/generate-mission/index.ts');
      final guides = read('supabase/functions/generate-quest-guides/index.ts');

      expect(guide, contains('planning_temporarily_unavailable'));
      expect(guide, isNot(contains('fallbackMissionRegeneration')));
      expect(guide, isNot(contains('fallbackGuideWithoutRecursion')));
      expect(guide, isNot(contains('local_mission_regeneration')));
      expect(mission, contains('mission_generation_temporarily_unavailable'));
      expect(mission, isNot(contains('fallbackMission')));
      expect(guides, contains('quest_guides_temporarily_unavailable'));
      expect(guides, isNot(contains('fallbackGuides')));
    },
  );

  test('configured Flutter services preserve input and expose retry paths', () {
    final intent = read(
      'apps/mobile/lib/features/quest/quest_intent_resolution_service.dart',
    );
    final regeneration = read(
      'apps/mobile/lib/features/mission/mission_regeneration_proposal_service.dart',
    );
    final arc = read('apps/mobile/lib/features/arc/arc_screen.dart');

    expect(intent, contains('QuestIntentUnavailableException'));
    expect(intent, contains('local_semantic_intent'));
    expect(regeneration, contains('MissionRegenerationUnavailableException'));
    expect(
      regeneration,
      isNot(contains('final MissionRegenerationProposalService fallback')),
    );
    expect(arc, contains('setState(() => _error = error.toString())'));
    expect(arc, contains('_isResolvingIntent = false'));
  });
}

Directory _repoRoot() {
  var current = Directory.current.absolute;
  while (true) {
    if (Directory('${current.path}/supabase/functions').existsSync()) {
      return current;
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      throw StateError('Repository root not found.');
    }
    current = parent;
  }
}
