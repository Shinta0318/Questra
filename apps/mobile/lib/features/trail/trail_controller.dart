import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'trail_model.dart';

final trailControllerProvider = NotifierProvider<TrailController, List<Trail>>(
  TrailController.new,
);

class TrailController extends Notifier<List<Trail>> {
  @override
  List<Trail> build() {
    return [
      Trail(
        questId: 'mock-quest-arc',
        title: 'Arcと最初の航路を描いた',
        summary: 'Questを6つのGuideへ分解し、Missionの入口を見つけた。',
        content: 'Questの輪郭がぼんやりしていたが、航路・知識・鍛錬・仲間・準備・機会に分けると次の一歩が見えた。',
        trailType: TrailType.questRecord,
      ),
      Trail(
        questId: 'mock-quest-arc',
        missionId: 'mock-mission-first-step',
        title: '今日のMissionを1つ完了',
        summary: '5分でできる小さな行動を完了した。',
        content: '完了したMissionはTrailとして残り、次のQuest判断に使える。',
        trailType: TrailType.missionRecord,
      ),
    ];
  }
}
