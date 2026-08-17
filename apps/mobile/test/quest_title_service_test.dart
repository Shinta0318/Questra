import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/quest_title_service.dart';

void main() {
  test('相談回答をQuest名から除外する', () {
    expect(
      QuestTitleService.normalize('シンガポールに行きたい\n- いつ頃までに叶えたい？ 2028/10/31'),
      'シンガポールへ行く',
    );
  });

  test('同じ行に続く相談回答をQuest名から除外する', () {
    expect(
      QuestTitleService.normalize('シンガポールに行きたい - いつ頃までに叶えたい？ 2028/10/31'),
      'シンガポールへ行く',
    );
  });

  test('空の候補では元の願いからQuest名を作る', () {
    expect(
      QuestTitleService.normalize('', fallback: '英語を話せるようになりたい'),
      '英語を話せるようになる',
    );
  });
}
