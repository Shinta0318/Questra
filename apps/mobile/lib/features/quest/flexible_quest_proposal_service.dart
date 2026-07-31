import 'quest_model.dart';

class FlexibleQuestProposal {
  const FlexibleQuestProposal({
    required this.title,
    required this.outcome,
    required this.fitReason,
    required this.firstStep,
    required this.difficulty,
    required this.estimatedDurationLabel,
  });

  final String title;
  final String outcome;
  final String fitReason;
  final String firstStep;
  final QuestDifficulty difficulty;
  final String estimatedDurationLabel;
}

abstract final class FlexibleQuestProposalService {
  static List<FlexibleQuestProposal> propose(String wish) {
    final input = wish.trim();
    if (!_isAmbiguous(input)) return const [];
    if (input.contains('英語')) {
      return const [
        FlexibleQuestProposal(
          title: '旅行先で英語の基本会話をする',
          outcome: '旅行で必要な会話を自分で行える',
          fitReason: '近い実用場面から始められる',
          firstStep: '使いたい場面を3つ書く',
          difficulty: QuestDifficulty.normal,
          estimatedDurationLabel: '約3か月',
        ),
        FlexibleQuestProposal(
          title: '海外の同僚と15分会話する',
          outcome: '仕事の近況を英語で共有できる',
          fitReason: '仕事で使う目的に絞れる',
          firstStep: '話す話題を一つ選ぶ',
          difficulty: QuestDifficulty.hard,
          estimatedDurationLabel: '約6か月',
        ),
        FlexibleQuestProposal(
          title: '英語資格で目標点を取る',
          outcome: '公式なスコアで到達を確認できる',
          fitReason: '測定できる目標にしたい場合に向く',
          firstStep: '受験候補と現在地を確認する',
          difficulty: QuestDifficulty.normal,
          estimatedDurationLabel: '約4か月',
        ),
      ];
    }
    return [
      FlexibleQuestProposal(
        title: '$inputを小さく試す',
        outcome: '自分に合う挑戦の形を見つける',
        fitReason: 'まだ条件が曖昧でも始められる',
        firstStep: '叶った状態を一文で書く',
        difficulty: QuestDifficulty.easy,
        estimatedDurationLabel: '約2週間',
      ),
      FlexibleQuestProposal(
        title: '$inputを習慣にする',
        outcome: '継続できる頻度と環境を整える',
        fitReason: '日常に定着させたい場合に向く',
        firstStep: '週に使える時間を記録する',
        difficulty: QuestDifficulty.normal,
        estimatedDurationLabel: '約3か月',
      ),
    ];
  }

  static bool _isAmbiguous(String value) =>
      value.length <= 24 && RegExp(r'たい|ようになりたい|始めたい').hasMatch(value);
}
