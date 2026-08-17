import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/arc_quest_guide_service.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/quest/planning_context.dart';

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
    '200-case corpus is retained while fixed local fallback stays disabled',
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
      expect(
        corpus.every(
          (item) =>
              (item['title'] as String).trim().isNotEmpty &&
              (item['description'] as String).trim().isNotEmpty &&
              item['planning_context'] is Map,
        ),
        isTrue,
      );
      final item = corpus.first;
      final quest = Quest(
        title: item['title'] as String,
        description: item['description'] as String,
        difficulty: QuestDifficulty.normal,
        status: QuestStatus.active,
        visibility: QuestVisibility.private,
        category: item['category'] as String,
      );
      await expectLater(
        service.generate(
          quest: quest,
          planningContext: PlanningContext.fromJson(
            Map<String, dynamic>.from(item['planning_context'] as Map),
          ),
        ),
        throwsStateError,
      );
    },
  );
}
