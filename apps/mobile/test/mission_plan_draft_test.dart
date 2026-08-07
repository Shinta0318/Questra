import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/mission/mission_plan_draft.dart';
import 'package:questra/features/quest/arc_quest_guide_service.dart';
import 'package:questra/features/quest/quest_guide_model.dart';

void main() {
  test('Mission completion contract is preserved in the editable plan', () {
    final guide = ArcQuestGuide(
      questId: 'quest-1',
      summary: 'summary',
      path: 'path',
      cautions: 'cautions',
      encouragement: 'encouragement',
      sourceType: 'test',
      missionCandidates: const [
        ArcMissionCandidate(
          title: '公式情報を確認する',
          description: '公式情報を確認したら完了です。',
          guideType: GuideType.knowledge,
          difficulty: MissionDifficulty.easy,
          doneCondition: '確認日とURLを記録する',
          expectedOutput: '確認済みURL',
          verificationType: 'official_source',
        ),
      ],
    );

    final candidate = MissionPlanDraft.fromArcGuide(
      guide,
      questTitle: '海外旅行をする',
    ).candidates.single;

    expect(candidate.doneCondition, '確認日とURLを記録する');
    expect(candidate.expectedOutput, '確認済みURL');
    expect(candidate.verificationType, 'official_source');
  });

  test('Arc guide becomes an editable Mission plan', () {
    final guide = ArcQuestGuide(
      questId: 'quest-1',
      summary: 'summary',
      path: 'path',
      cautions: 'cautions',
      encouragement: 'encouragement',
      sourceType: 'test',
      missionCandidates: List.generate(
        3,
        (index) => ArcMissionCandidate(
          title: 'Mission $index',
          description: 'Description $index',
          guideType: GuideType.route,
          difficulty: MissionDifficulty.easy,
        ),
      ),
    );

    final draft = MissionPlanDraft.fromArcGuide(
      guide,
      questTitle: 'Launch Questra',
    );

    expect(draft.candidates, hasLength(3));
    expect(draft.candidates.first.title, 'Mission 0');
  });

  test('Mission plan supports editing, reorder, today, and 30 item cap', () {
    var draft = MissionPlanDraft(
      candidates: [
        MissionCandidateDraft(
          title: 'A',
          description: 'A description',
          guideType: GuideType.route,
          difficulty: MissionDifficulty.easy,
        ),
        MissionCandidateDraft(
          title: 'B',
          description: 'B description',
          guideType: GuideType.training,
          difficulty: MissionDifficulty.normal,
        ),
        MissionCandidateDraft(
          title: 'C',
          description: 'C description',
          guideType: GuideType.knowledge,
          difficulty: MissionDifficulty.easy,
        ),
      ],
    );
    final first = draft.candidates.first;
    final last = draft.candidates.last;

    draft = draft.update(first.copyWith(title: 'Edited'));
    draft = draft.move(0, 2).markToday(last.id);
    expect(draft.candidates.last.title, 'Edited');
    expect(
      draft.candidates.where((candidate) => candidate.isToday),
      hasLength(1),
    );

    while (draft.candidates.length < 30) {
      draft = draft.add();
    }
    expect(draft.add().candidates, hasLength(30));
  });

  test('empty Mission titles are excluded from confirmation', () {
    final draft = MissionPlanDraft(
      candidates: [
        MissionCandidateDraft(
          title: 'Keep',
          description: '',
          guideType: GuideType.route,
          difficulty: MissionDifficulty.easy,
        ),
        MissionCandidateDraft(
          title: ' ',
          description: '',
          guideType: GuideType.route,
          difficulty: MissionDifficulty.easy,
        ),
      ],
    );

    expect(draft.validCandidates, hasLength(1));
  });
}
