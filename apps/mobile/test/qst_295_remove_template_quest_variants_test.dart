import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = _repoRoot();
  String read(String path) => File('${root.path}/$path').readAsStringSync();

  test('Arc Quest UI has no legacy template variant controls', () {
    final arc = read('apps/mobile/lib/features/arc/arc_screen.dart');

    expect(arc, isNot(contains('近いQuestの形')));
    expect(arc, isNot(contains('選んだ案を組み合わせる')));
    expect(arc, isNot(contains('FlexibleQuestProposal')));
    expect(arc, contains('Arcと一緒にQuestを整理'));
    expect(arc, contains('ArcがまとめたQuest'));
    expect(arc, contains('このQuestで進む'));
    expect(arc, contains('Arcともう少し相談する'));
  });

  test('server intent contract does not force candidate directions', () {
    final edge = read('supabase/functions/arc-quest-guide/index.ts');

    expect(edge, contains('mode === "quest_intent"'));
    expect(edge, contains('clarity !== "multiple_directions"'));
    expect(edge, contains('maxItems: 3'));
    expect(edge, isNot(contains('mode === "quest_alternatives"')));
    expect(edge, isNot(contains('minItems: 2')));
  });

  test('Quest DNA stores semantic Quest type with legacy compatibility', () {
    final dna = read('apps/mobile/lib/features/quest/quest_dna.dart');

    expect(dna, contains("'quest_type'"));
    expect(dna, contains('classifyQuestType(source).storageKey'));
    expect(dna, contains("?? '未評価'"));
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
