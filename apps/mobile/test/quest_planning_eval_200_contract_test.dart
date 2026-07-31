import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/arc_quest_guide_service.dart';
import 'package:questra/features/quest/quest_model.dart';

void main() {
  test('evaluation builder defines four context variants per seed', () {
    final root = Directory.current.parent.parent;
    final script = File(
      '${root.path}/tools/qst/build_quest_planning_eval_200.ps1',
    ).readAsStringSync();
    expect(script, contains('beginner'));
    expect(script, contains('busy'));
    expect(script, contains('low_budget'));
    expect(script, contains('experienced'));
    expect(script, contains('200'));
  });

  test(
    'local fallback keeps all 200 cases inside planning contracts',
    () async {
      final root = Directory.current.parent.parent;
      final corpus =
          (jsonDecode(
                    File(
                      '${root.path}/tools/qst/quest_planning_eval_200.json',
                    ).readAsStringSync(),
                  )
                  as List)
              .cast<Map<String, dynamic>>();
      const service = LocalArcQuestGuideService();

      expect(corpus, hasLength(200));
      for (final item in corpus) {
        final quest = Quest(
          title: item['title'] as String,
          description: item['description'] as String,
          difficulty: QuestDifficulty.normal,
          status: QuestStatus.active,
          visibility: QuestVisibility.private,
          category: item['category'] as String,
        );
        final guide = await service.generate(quest: quest);
        final titles = guide.missionCandidates
            .map((mission) => mission.title.trim().toLowerCase())
            .toList(growable: false);

        expect(
          guide.missionCandidates.length,
          inInclusiveRange(3, 30),
          reason: item['id'] as String,
        );
        expect(
          titles.toSet(),
          hasLength(titles.length),
          reason: item['id'] as String,
        );
        expect(
          titles,
          isNot(contains(quest.title.trim().toLowerCase())),
          reason: item['id'] as String,
        );
        expect(
          guide.missionCandidates.every(
            (mission) =>
                mission.doneCondition.isNotEmpty &&
                mission.expectedOutput.isNotEmpty &&
                mission.description.contains('完了です'),
          ),
          isTrue,
          reason: item['id'] as String,
        );
      }
    },
  );
}
