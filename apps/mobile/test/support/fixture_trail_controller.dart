import 'package:questra/features/trail/trail_controller.dart';
import 'package:questra/features/trail/trail_model.dart';

class FixtureTrailController extends TrailController {
  @override
  List<Trail> build() {
    return [
      Trail(
        questId: 'fixture-quest',
        title: 'Beta準備の一歩を記録した',
        summary: '確認した内容を自分の言葉で残した。',
        content: 'このTrailは画面テスト専用で、本番の初期状態には含まれません。',
        trailType: TrailType.questRecord,
      ),
    ];
  }
}
