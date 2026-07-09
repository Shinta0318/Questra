import 'quest_model.dart';
import 'quest_template_model.dart';

class QuestTemplateLibrary {
  const QuestTemplateLibrary();

  List<QuestTemplate> get templates => const [
    QuestTemplate(
      id: 'travel',
      title: '旅のQuestを始める',
      category: '旅行',
      description: '行きたい場所を決め、準備と現地での体験を小さなMissionに分けます。',
      difficulty: QuestDifficulty.normal,
      milestones: [
        QuestTemplateMilestone(
          title: '目的地を決める',
          description: '候補を3つ出して、行く理由を一言で書く。',
        ),
        QuestTemplateMilestone(
          title: '準備を整える',
          description: '日程、予算、持ち物、予約の不安を洗い出す。',
        ),
        QuestTemplateMilestone(
          title: 'Trailを残す',
          description: '旅で見つけた景色や学びをTrailにする。',
        ),
      ],
      missions: [
        QuestTemplateMission(
          title: '行きたい場所を3つ書く',
          description: '写真やメモを見ながら候補を並べる。',
        ),
        QuestTemplateMission(
          title: '必要な予約を1つ確認する',
          description: '交通、宿、チケットのどれかを調べる。',
        ),
      ],
    ),
    QuestTemplate(
      id: 'health',
      title: '健康習慣を作る',
      category: '健康',
      description: '無理のない運動、睡眠、食事の小さな習慣を作ります。',
      difficulty: QuestDifficulty.easy,
      milestones: [
        QuestTemplateMilestone(
          title: '現状を知る',
          description: '睡眠、運動、食事で変えたい点を1つ選ぶ。',
        ),
        QuestTemplateMilestone(
          title: '小さく始める',
          description: '10分以内で続けられるMissionを決める。',
        ),
        QuestTemplateMilestone(
          title: '続け方を調整する',
          description: 'Trailを見返して無理のないリズムに直す。',
        ),
      ],
      missions: [
        QuestTemplateMission(
          title: '10分だけ歩く',
          description: '距離ではなく、外に出ることを達成にする。',
        ),
        QuestTemplateMission(
          title: '寝る前の画面時間を減らす',
          description: '今日は15分だけ早く閉じる。',
        ),
      ],
    ),
    QuestTemplate(
      id: 'learning',
      title: '新しいスキルを学ぶ',
      category: '学習',
      description: '学びたいテーマを分解し、毎週の練習と振り返りで進めます。',
      difficulty: QuestDifficulty.normal,
      milestones: [
        QuestTemplateMilestone(
          title: '学ぶ理由を決める',
          description: 'できるようになりたい場面を具体化する。',
        ),
        QuestTemplateMilestone(
          title: '教材を1つ選ぶ',
          description: '最初の一冊、動画、講座など入口を決める。',
        ),
        QuestTemplateMilestone(
          title: '成果を見える化する',
          description: '学んだことをTrailや小さな作品に残す。',
        ),
      ],
      missions: [
        QuestTemplateMission(title: '15分だけ学ぶ', description: '完璧より、最初のページを開く。'),
        QuestTemplateMission(
          title: '学んだことを3行で書く',
          description: 'Trailとして一つ記録する。',
        ),
      ],
    ),
    QuestTemplate(
      id: 'family',
      title: '大切な人との時間を作る',
      category: '家族',
      description: '家族や身近な人との時間を、予定ではなく小さな思いやりから作ります。',
      difficulty: QuestDifficulty.easy,
      milestones: [
        QuestTemplateMilestone(
          title: '相手を一人決める',
          description: '今いちばん時間を取りたい相手を選ぶ。',
        ),
        QuestTemplateMilestone(
          title: '小さな連絡をする',
          description: '短いメッセージや声かけから始める。',
        ),
        QuestTemplateMilestone(
          title: '一緒に過ごす予定を作る',
          description: '負担の少ない時間を一つ置く。',
        ),
      ],
      missions: [
        QuestTemplateMission(
          title: 'ありがとうを一つ伝える',
          description: '短くてもよいので今日伝える。',
        ),
        QuestTemplateMission(
          title: '一緒にできることを1つ聞く',
          description: '相手の都合に合わせる。',
        ),
      ],
    ),
    QuestTemplate(
      id: 'work',
      title: '仕事の挑戦を進める',
      category: '仕事',
      description: '曖昧な仕事の挑戦を、成果物・相談・締切に分けて前へ進めます。',
      difficulty: QuestDifficulty.hard,
      milestones: [
        QuestTemplateMilestone(
          title: '成果物を定義する',
          description: '何ができたら完了かを一文にする。',
        ),
        QuestTemplateMilestone(
          title: '最初の相談をする',
          description: '詰まりそうな点を早めに共有する。',
        ),
        QuestTemplateMilestone(
          title: '仕上げて見せる',
          description: '小さくても形にしてフィードバックをもらう。',
        ),
      ],
      missions: [
        QuestTemplateMission(title: '完了条件を3つ書く', description: 'できたと言える状態を分ける。'),
        QuestTemplateMission(title: '相談相手を一人決める', description: '今日聞ける人を選ぶ。'),
      ],
    ),
    QuestTemplate(
      id: 'challenge',
      title: '勇気のいる挑戦を始める',
      category: '挑戦',
      description: '少し怖いけれど大切な挑戦を、安全な一歩から始めます。',
      difficulty: QuestDifficulty.hard,
      milestones: [
        QuestTemplateMilestone(
          title: '怖さを言葉にする',
          description: '何が不安かを責めずに書き出す。',
        ),
        QuestTemplateMilestone(
          title: '安全な一歩を選ぶ',
          description: '失敗しても戻れる行動を一つ決める。',
        ),
        QuestTemplateMilestone(
          title: '挑戦を記録する',
          description: 'できたこと、怖かったこと、次の一歩をTrailに残す。',
        ),
      ],
      missions: [
        QuestTemplateMission(title: '怖い理由を3つ書く', description: '判断せずに並べる。'),
        QuestTemplateMission(title: '5分でできる一歩を試す', description: '小ささを大事にする。'),
      ],
    ),
  ];

  QuestTemplate? findById(String id) {
    for (final template in templates) {
      if (template.id == id) {
        return template;
      }
    }
    return null;
  }
}
