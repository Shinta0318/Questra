import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/mission/mission_regeneration_intent.dart';
import 'package:questra/features/mission/mission_regeneration_proposal_service.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/quest/route_replanning_model.dart';

Quest quest() => Quest(
  title: '富士山に登る',
  description: '安全に登頂する',
  difficulty: QuestDifficulty.hard,
  status: QuestStatus.active,
  visibility: QuestVisibility.private,
);

Mission mission({MissionStatus status = MissionStatus.todo}) => Mission(
  questId: 'q',
  questTitle: '富士山に登る',
  title: '装備を準備する',
  description: '装備一覧を確認したら完了です。',
  guideType: GuideType.route,
  difficulty: MissionDifficulty.easy,
  status: status,
);

void main() {
  const service = LocalMissionRegenerationProposalService();

  test(
    'creates one explicit replacement without mutating the Mission',
    () async {
      final current = mission();
      final proposal = await service.propose(
        quest: quest(),
        mission: current,
        intent: MissionRegenerationIntent.smaller,
      );
      expect(proposal.items, hasLength(1));
      expect(proposal.items.single.action, RouteChangeAction.replace);
      expect(proposal.items.single.safetyLevel, 3);
      expect(proposal.items.single.beforeData['title'], current.title);
      expect(proposal.items.single.afterData['title'], contains('15分'));
      expect(current.title, '装備を準備する');
    },
  );

  test('completed Mission cannot be regenerated', () async {
    expect(
      () => service.propose(
        quest: quest(),
        mission: mission(status: MissionStatus.completed),
        intent: MissionRegenerationIntent.smaller,
      ),
      throwsStateError,
    );
  });
}
