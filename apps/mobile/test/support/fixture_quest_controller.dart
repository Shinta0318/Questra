import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_model.dart';

class FixtureQuestController extends QuestController {
  @override
  List<Quest> build() {
    return [
      Quest(
        title: 'Questraをローンチする',
        description: '最初の航路を整えてBetaへ進む',
        difficulty: QuestDifficulty.normal,
        status: QuestStatus.active,
        visibility: QuestVisibility.private,
        category: 'プロダクト',
      ),
    ];
  }
}
