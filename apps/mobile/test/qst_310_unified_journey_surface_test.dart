import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/widgets/layout/questra_journey_scaffold.dart';
import 'package:questra/widgets/layout/questra_screen_surface.dart';

void main() {
  testWidgets('Journey scaffold provides the semantic title and cosmic surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: QuestraJourneyScaffold(
          title: 'Mission',
          child: Text('航路'),
        ),
      ),
    );

    expect(find.text('Mission'), findsOneWidget);
    expect(find.text('航路'), findsOneWidget);
    expect(find.byType(QuestraScreenSurface), findsOneWidget);
    expect(find.byType(SafeArea), findsWidgets);
  });

  test('Mission Task Trail lists use the shared Journey surface', () {
    for (final path in [
      'lib/features/mission/mission_screen.dart',
      'lib/features/task/task_screen.dart',
      'lib/features/trail/trail_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('QuestraJourneyScaffold('), reason: path);
    }
  });
}
