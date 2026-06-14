import '../arc/arc_emotion.dart';
import 'quest_guide_model.dart';
import 'quest_model.dart';

class QuestDecompositionBundle {
  const QuestDecompositionBundle({
    required this.guides,
    required this.advice,
    required this.starMap,
  });

  final List<QuestGuide> guides;
  final List<ArcAdvice> advice;
  final List<StarMapItem> starMap;
}

class QuestDecompositionService {
  const QuestDecompositionService();

  QuestDecompositionBundle generateForQuest(Quest quest) {
    final guides = GuideType.values
        .map(
          (guideType) => QuestGuide(
            questId: quest.id,
            guideType: guideType,
            title: _guideTitle(quest.title, guideType),
            description: _guideDescription(quest, guideType),
            suggestedActions: _suggestedActions(guideType),
          ),
        )
        .toList();

    final advice = guides
        .map(
          (guide) => ArcAdvice(
            questId: quest.id,
            guideType: guide.guideType,
            adviceText: _adviceText(quest.title, guide.guideType),
            emotion: _emotionForGuide(guide.guideType),
          ),
        )
        .toList();

    final starMap = guides
        .map(
          (guide) => StarMapItem(
            questId: quest.id,
            guideType: guide.guideType,
            title: '${guide.guideType.label}の参考星',
            description: '${quest.title}の航路を支える中立的な外部素材です。',
            url: 'https://example.com/${guide.guideType.name}',
            contentType: _contentTypeForGuide(guide.guideType),
          ),
        )
        .toList();

    return QuestDecompositionBundle(
      guides: guides,
      advice: advice,
      starMap: starMap,
    );
  }

  String _guideTitle(String questTitle, GuideType guideType) {
    return '${guideType.label}: $questTitle';
  }

  String _guideDescription(Quest quest, GuideType guideType) {
    return switch (guideType) {
      GuideType.route => '${quest.title}までの航路を見える形にします。',
      GuideType.knowledge => '最初に学ぶべき知識を見つけます。',
      GuideType.training => 'くり返せる最小の練習に分けます。',
      GuideType.guild => '前進を支えてくれるGuildの仲間や場を探します。',
      GuideType.resource => '必要な道具、参考素材、環境を整えます。',
      GuideType.opportunity => '広告やオファーではない、前へ進むための機会を見つけます。',
    };
  }

  List<String> _suggestedActions(GuideType guideType) {
    return switch (guideType) {
      GuideType.route => ['到達点を書く', '3つの通過点を選ぶ', '次の目印を決める'],
      GuideType.knowledge => ['知らないことを並べる', '初心者向け資料を1つ読む', 'Arcへの質問を1つ書く'],
      GuideType.training => ['10分だけ練習する', '基本動作を1回くり返す', '難しかった点を記録する'],
      GuideType.guild => ['助けになりそうな仲間を1人思い出す', '関係するGuildの場を探す', '小さな質問を1つ投げる'],
      GuideType.resource => ['役立つ道具を1つ保存する', '作業場所を整える', '詰まりを1つ外す'],
      GuideType.opportunity => ['参加できる場を1つ探す', '学びの機会を1つ保存する', '次に開ける扉を1つ選ぶ'],
    };
  }

  String _adviceText(String questTitle, GuideType guideType) {
    return switch (guideType) {
      GuideType.route => '「$questTitle」は大切な星になりそうだね。走る前に、まず航路を見える形にしよう。',
      GuideType.knowledge => '足りない知識はひとつずつ重ねれば大丈夫。星図は少しずつ明るくなるよ。',
      GuideType.training => '今日は小さな練習を1回だけ選ぼう。5分の集中も、ちゃんと前進だよ。',
      GuideType.guild => 'Guildでは大きな声より、はっきりした小さな質問が道しるべになるよ。',
      GuideType.resource => '次のMissionを助けるものだけ持とう。荷物が軽いほど遠くへ進めるよ。',
      GuideType.opportunity => '探すのは売り込みではなく、君の航路を広げる入口だよ。',
    };
  }

  ArcEmotion _emotionForGuide(GuideType guideType) {
    return switch (guideType) {
      GuideType.route => ArcEmotion.serious,
      GuideType.knowledge => ArcEmotion.normal,
      GuideType.training => ArcEmotion.support,
      GuideType.guild => ArcEmotion.excited,
      GuideType.resource => ArcEmotion.normal,
      GuideType.opportunity => ArcEmotion.celebrate,
    };
  }

  String _contentTypeForGuide(GuideType guideType) {
    return switch (guideType) {
      GuideType.route => 'framework',
      GuideType.knowledge => 'article',
      GuideType.training => 'exercise',
      GuideType.guild => 'guild',
      GuideType.resource => 'tool',
      GuideType.opportunity => 'event',
    };
  }
}
