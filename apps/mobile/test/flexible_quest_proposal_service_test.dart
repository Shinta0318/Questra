import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/flexible_quest_proposal_service.dart';

void main() {
  test('ambiguous wishes receive distinct optional Quest directions', () {
    final options = FlexibleQuestProposalService.propose('英語が話せるようになりたい');
    expect(options, hasLength(3));
    expect(options.map((item) => item.outcome).toSet(), hasLength(3));
    expect(
      FlexibleQuestProposalService.propose('2027年3月までにTOEIC700点を取る'),
      isEmpty,
    );
  });
}
