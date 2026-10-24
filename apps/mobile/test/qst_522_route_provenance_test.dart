import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/route_replanning_model.dart';
import 'package:questra/features/quest/route_replanning_presentation.dart';

void main() {
  RouteChangeProposal proposal(RouteProposalProvenance provenance) =>
      RouteChangeProposal(
        questId: 'quest',
        reason: RouteProposalReason.manualReview,
        summary: '航路を見直します',
        confidence: 0.8,
        items: [
          RouteChangeItem(
            action: RouteChangeAction.add,
            title: '次の行動',
            reason: '進捗に合わせて追加します',
            beforeData: const {},
            afterData: const {'title': '次の行動'},
          ),
        ],
        provenance: provenance,
      );

  test('legacy rows never claim Gemini provenance', () {
    final legacy = RouteProposalProvenance.fromStorage(const {});
    expect(legacy.generator, RouteProposalGenerator.legacyUnknown);
    expect(routeProposalSourceLabel(proposal(legacy)), contains('確認できない'));
    final unrecognized = RouteProposalProvenance.fromStorage(const {
      'generator_type': 'future_engine',
    });
    expect(unrecognized.generator, RouteProposalGenerator.legacyUnknown);
  });

  test('rules and Gemini proposals remain visibly distinct', () {
    final rules = proposal(
      const RouteProposalProvenance(
        generator: RouteProposalGenerator.rules,
        version: 'adaptive-route-v1',
      ),
    );
    expect(routeProposalSourceLabel(rules), contains('進捗'));
    expect(routeProposalSourceLabel(rules), isNot(contains('AI')));
    final gemini = proposal(
      RouteProposalProvenance.fromStorage(const {
        'generator_type': 'gemini',
        'generator_version': 'gemini-pinned',
        'prompt_version': 'route-v1',
        'schema_version': 'route-proposal-v1',
        'grounded': false,
      }),
    );
    expect(gemini.provenance.version, 'gemini-pinned');
    expect(routeProposalSourceLabel(gemini), contains('AI'));
    expect(gemini.copyWith(status: RouteProposalStatus.accepted).provenance,
        same(gemini.provenance));
  });
}
