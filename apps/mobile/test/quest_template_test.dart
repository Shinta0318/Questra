import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/quest/quest_template_library.dart';

void main() {
  const library = QuestTemplateLibrary();

  test('template library covers core beta Quest categories', () {
    final categories = library.templates.map((template) => template.category);

    expect(categories, containsAll(['旅行', '健康', '学習', '家族', '仕事', '挑戦']));
  });

  test('templates include editable Quest fields and suggestions', () {
    final template = library.findById('learning')!;

    expect(template.title, isNotEmpty);
    expect(template.description, isNotEmpty);
    expect(template.category, '学習');
    expect(template.difficulty, QuestDifficulty.normal);
    expect(template.milestones.length, greaterThanOrEqualTo(3));
    expect(template.missions.length, greaterThanOrEqualTo(2));
  });
}
