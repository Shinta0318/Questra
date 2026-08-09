import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/theme/app_theme.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_detail_screen.dart';
import 'package:questra/features/task/task_controller.dart';

import '../integration_test/support/qst_269_core_journey_scenario.dart';

void main() {
  setUpAll(() async {
    if (!Platform.isWindows) return;
    final bytes = await File(r'C:\Windows\Fonts\meiryo.ttc').readAsBytes();
    final loader = FontLoader('QstJapanese')
      ..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
    await loader.load();
  });

  testWidgets('Mission詳細のcompact修正後Goldenを保持する', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          missionControllerProvider.overrideWith(
            Qst269JourneyMissionController.new,
          ),
          taskControllerProvider.overrideWith(
            Qst269CompletedTaskController.new,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light.copyWith(
            textTheme: AppTheme.light.textTheme.apply(
              fontFamily: 'QstJapanese',
            ),
            primaryTextTheme: AppTheme.light.primaryTextTheme.apply(
              fontFamily: 'QstJapanese',
            ),
          ),
          home: const MissionDetailScreen(missionId: 'mission-e2e'),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(MissionDetailScreen),
      matchesGoldenFile('goldens/qst_269_mission_detail_after_390.png'),
    );
  }, skip: !Platform.isWindows);
}
