import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/router/app_routes.dart';

void main() {
  test('Trail composer route can preselect a newly created Mission', () {
    final location = AppRoutes.trailComposerForQuest(
      'quest-a',
      missionId: 'mission-new',
    );

    expect(location, '/trail?questId=quest-a&missionId=mission-new&create=1');
    final uri = Uri.parse(location);
    expect(uri.queryParameters['questId'], 'quest-a');
    expect(uri.queryParameters['missionId'], 'mission-new');
    expect(uri.queryParameters['create'], '1');
  });
}
