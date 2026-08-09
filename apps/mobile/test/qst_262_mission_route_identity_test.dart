import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root =
      Directory.current.path.endsWith('${Platform.pathSeparator}mobile')
      ? Directory.current.parent.parent
      : Directory.current;

  String read(String path) => File('${root.path}/$path').readAsStringSync();

  test('Mission screen identity never changes with Task availability', () {
    final source = read('apps/mobile/lib/features/mission/mission_screen.dart');

    expect(source, contains('MissionCard('));
    expect(source, isNot(contains('return const TaskScreen()')));
    expect(source, isNot(contains('.updateProgress(')));
    expect(source, isNot(contains('Missionを完了')));
  });

  test('Mission and Task lists have distinct stable routes', () {
    final routes = read('apps/mobile/lib/core/router/app_routes.dart');
    final router = read('apps/mobile/lib/core/router/app_router.dart');
    final taskScreen = read('apps/mobile/lib/features/task/task_screen.dart');

    expect(routes, contains("static const mission = '/mission'"));
    expect(routes, contains("static const task = '/task'"));
    expect(router, contains('path: AppRoutes.mission'));
    expect(router, contains('path: AppRoutes.task'));
    expect(taskScreen, contains('context.push('));
  });

  test('Task-derived presentation does not use editable Mission progress', () {
    final presentation = read(
      'apps/mobile/lib/features/mission/widgets/mission_card_presentation.dart',
    );
    final detail = read(
      'apps/mobile/lib/features/mission/mission_detail_screen.dart',
    );

    expect(presentation, isNot(contains('fallbackProgress')));
    expect(detail, contains("'Taskはまだありません'"));
    expect(detail, isNot(contains('Mission進捗 \${mission.progressPercent}%')));
  });
}
