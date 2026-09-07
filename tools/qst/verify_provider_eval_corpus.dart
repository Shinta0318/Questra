import 'dart:convert';
import 'dart:io';

const planningPath = 'tools/qst/quest_planning_eval_200.json';
const safetyPath = 'tools/qst/quest_planning_safety_eval_cases.json';
const requiredPersonas = <String>{
  'beginner',
  'experienced',
  'busy',
  'low_budget',
  'high_budget',
  'with_children',
  'solo',
  'group',
  'short_deadline',
  'long_deadline',
  'rural',
  'overseas',
  'information_poor',
  'multi_constraint',
};

void main() {
  final failures = <String>[];
  final planning = _list(planningPath, failures);
  final safety = _list(safetyPath, failures);
  if (planning.length != 200)
    failures.add('Planning corpus must contain exactly 200 cases.');
  if (safety.length < 10)
    failures.add('Safety corpus must contain at least 10 cases.');

  final ids = <String>{};
  final wishes = <String>{};
  final categories = <String>{};
  final personas = <String>{};
  for (final row in planning) {
    final id = row['id']?.toString().trim() ?? '';
    if (id.isEmpty || !ids.add(id))
      failures.add('Missing or duplicate planning ID: $id');
    final title = row['title']?.toString().trim() ?? '';
    final description = row['description']?.toString().trim() ?? '';
    if (title.isEmpty || description.isEmpty)
      failures.add('$id lacks title or description.');
    wishes.add('$title\n$description');
    categories.add(row['category']?.toString() ?? '');
    personas.add(row['persona']?.toString() ?? '');
    final keywords = row['expected_keywords'];
    if (keywords is! List || keywords.length < 3)
      failures.add('$id lacks evaluation keywords.');
    final context = row['planning_context'];
    if (context is! Map ||
        context['consent_granted'] != true ||
        (context['weekly_minutes'] is! num) ||
        (context['weekly_minutes'] as num) <= 0 ||
        context['preferences'] is! List ||
        (context['preferences'] as List).isEmpty) {
      failures.add('$id has an invalid planning context.');
    }
  }
  if (wishes.length < 50)
    failures.add('At least 50 unique wishes are required.');
  if (categories.where((value) => value.isNotEmpty).length < 12) {
    failures.add('At least 12 categories are required.');
  }
  final missingPersonas = requiredPersonas.difference(personas);
  if (missingPersonas.isNotEmpty)
    failures.add('Missing personas: ${missingPersonas.join(', ')}');

  final safetyIds = <String>{};
  final actions = <String>{};
  for (final row in safety) {
    final id = row['id']?.toString().trim() ?? '';
    if (id.isEmpty || !safetyIds.add(id) || ids.contains(id)) {
      failures.add('Missing or duplicate safety ID: $id');
    }
    actions.add(row['expected_action']?.toString() ?? '');
  }
  for (final action in const ['allow', 'block', 'reframe']) {
    if (!actions.contains(action))
      failures.add('Safety corpus lacks $action cases.');
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Provider evaluation corpus verification failed:');
    for (final failure in failures) stderr.writeln('- $failure');
    exit(1);
  }
  stdout.writeln(
    'Provider corpus passed: ${planning.length} planning, ${safety.length} safety, '
    '${wishes.length} wishes, ${categories.length} categories, ${personas.length} personas.',
  );
}

List<Map<String, dynamic>> _list(String path, List<String> failures) {
  final file = File(path);
  if (!file.existsSync()) {
    failures.add('Missing $path');
    return [];
  }
  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! List) throw const FormatException('root must be an array');
    return decoded.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  } catch (error) {
    failures.add('Invalid JSON in $path: $error');
    return [];
  }
}
