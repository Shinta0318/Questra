import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:questra/features/arc/arc_screen.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/quest/quest_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets(
    'planning failure keeps the wish and manual recovery creates no missions',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const ArcScreen()),
          GoRoute(
            path: '/quest/:questId',
            builder: (_, state) => Text(
              'Quest ${state.pathParameters['questId']}',
              textDirection: TextDirection.ltr,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      const wish = '2028年10月までにシンガポールへ一人で旅行したい';
      await tester.enterText(
        find.byKey(const ValueKey('arc-chat-input')),
        wish,
      );
      await tester.tap(find.byTooltip('メッセージを送信'));
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final start = find.widgetWithText(FilledButton, 'Questとして始める');
      await tester.ensureVisible(start.first);
      await tester.tap(start.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(wish), findsAtLeastNWidgets(1));
      final proceed = find.widgetWithText(FilledButton, 'このQuestで進む');
      await tester.ensureVisible(proceed);
      await tester.tap(proceed);
      await tester.pump();

      final generate = find.widgetWithText(FilledButton, 'Arcと航路を描く');
      await tester.ensureVisible(generate);
      await tester.tap(generate);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('arc-planning-recovery')), findsOneWidget);
      expect(find.textContaining('入力内容は残っています'), findsOneWidget);
      expect(find.textContaining('Bad state'), findsNothing);
      expect(find.textContaining('Gemini Planning API'), findsNothing);
      expect(container.read(questControllerProvider), isEmpty);
      expect(container.read(missionControllerProvider), isEmpty);

      final manual = find.widgetWithText(OutlinedButton, 'Questだけ手動で整える');
      await tester.ensureVisible(manual);
      await tester.tap(manual);
      await tester.pump();

      expect(find.byKey(const Key('arc-manual-quest-card')), findsOneWidget);
      expect(find.textContaining('Missionは作らず'), findsOneWidget);

      final save = find.byKey(const Key('save-quest-without-plan'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.tap(save);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(container.read(questControllerProvider), hasLength(1));
      expect(container.read(questControllerProvider).single.title, isNot(wish));
      expect(container.read(missionControllerProvider), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
