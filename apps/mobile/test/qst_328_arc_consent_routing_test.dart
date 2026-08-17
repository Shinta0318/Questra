import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Arc Edge Function minimizes context and fails closed', () {
    final source = File(
      '../../supabase/functions/arc-chat/index.ts',
    ).readAsStringSync();

    expect(source, contains('contextForIntent(routingHint, payload.context)'));
    expect(source, contains('intentType === "active_quest_support"'));
    expect(source, contains('safetyStatus === "allowed"'));
    expect(source, isNot(contains('fallbackQuestSuggestion')));
    expect(
      source,
      contains(
        'return { active_quests: [], recent_missions: [], recent_tasks: [], recent_trails: [], memories: [] }',
      ),
    );
  });

  test('Arc screen exposes explicit consent and decline controls', () {
    final source = File('lib/features/arc/arc_screen.dart').readAsStringSync();

    expect(source, contains('Questとして始める'));
    expect(source, contains('相談として続ける'));
    expect(source, contains('_declinedQuestInputs'));
    expect(source, contains('_normalizeQuestInput(suggestion.sourceInput)'));
  });
}
