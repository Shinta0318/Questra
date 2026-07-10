import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:questra/features/arc/arc_screen.dart';
import 'package:questra/features/guild/guild_screen.dart';
import 'package:questra/features/home/home_screen.dart';
import 'package:questra/features/mission/mission_screen.dart';
import 'package:questra/features/onboarding/onboarding_screen.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_detail_screen.dart';
import 'package:questra/features/profile/profile_screen.dart';
import 'package:questra/features/quest/quest_screen.dart';
import 'package:questra/features/trail/trail_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ja_JP'));

  final screens = <String, Widget>{
    'Home': const HomeScreen(),
    'Quest': const QuestScreen(),
    'Mission': const MissionScreen(),
    'Trail': const TrailScreen(),
    'Guild': const GuildScreen(),
    'Arc Chat': const ArcScreen(),
    'Profile': const ProfileScreen(),
    'Onboarding': const OnboardingScreen(),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} renders at compact width with large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        ProviderScope(child: MaterialApp(home: entry.value)),
      );
      await tester.pump();

      final exception = tester.takeException();
      if (exception is FlutterError) {
        fail(exception.toStringDeep());
      }
      expect(exception, isNull);
    });
  }

  testWidgets('Home orders beta journey sections without mock ownership', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: HomeScreen())),
    );
    await tester.pump();

    expect(find.text('Home → Arc → Quest'), findsOneWidget);
    expect(find.text('今日のMission'), findsOneWidget);
    expect(find.text('Missionへ'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('進行中のQuest'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('進行中のQuest'), findsOneWidget);
    expect(find.text('すべて見る'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('最近のTrail'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('最近のTrail'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Guildの動き'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Guildの動き'), findsOneWidget);
  });

  testWidgets('Quest Detail exposes journey overview and next action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, child) {
              final questId = ref.watch(questControllerProvider).first.id;
              return QuestDetailScreen(questId: questId);
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('旅路の概要 /'), findsOneWidget);
    expect(find.text('次の一歩'), findsOneWidget);
    expect(find.text('進捗'), findsWidgets);
    expect(find.text('Mission'), findsWidgets);
    expect(find.text('Trail'), findsWidgets);
    expect(find.text('Theme'), findsWidgets);
    expect(find.text('Adventure Map'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Quest DNA Snapshot'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Quest DNA Snapshot'), findsOneWidget);
    expect(find.text('推定'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Quest DNAを見直す'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Quest DNAを見直す'), findsOneWidget);
    await tester.ensureVisible(find.text('Quest DNAを見直す'));
    await tester.pump();
    await tester.tap(find.text('Quest DNAを見直す'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Quest DNAの見直し'), findsOneWidget);
    expect(find.text('推定値・未保存'), findsWidgets);
    Navigator.of(tester.element(find.text('Quest DNAの見直し'))).pop();
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Challenge Graph Preview'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Challenge Graph Preview'), findsOneWidget);
    expect(find.text('星図ノード'), findsOneWidget);
    expect(find.text('Nodes'), findsWidgets);
    expect(find.text('Edges'), findsWidgets);
    expect(find.text('Arc Graph Insight'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Quest支援の透明性'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Quest支援の透明性'), findsOneWidget);
    expect(find.text('Betaでは未接続'), findsOneWidget);
  });

  testWidgets('Quest cards expose accessible labels and progress values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: QuestScreen())),
    );
    await tester.pump();

    final questCardSemantics = tester.widgetList<Semantics>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.label ?? '').contains('Questを開く'),
      ),
    );

    expect(questCardSemantics, isNotEmpty);
    expect(questCardSemantics.first.properties.value, contains('進捗'));
    expect(questCardSemantics.first.properties.button, isTrue);
  });

  testWidgets('Guild feed exposes coherent Japanese support sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: GuildScreen())),
    );
    await tester.pump();

    expect(find.text('Guildの現在地'), findsOneWidget);
    expect(find.text('相談ドラフト'), findsOneWidget);
    expect(find.text('Question Draft'), findsNothing);
    expect(find.text('Copy question'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('近いQuest'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('近いQuest'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('共有しやすいTrail'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('共有しやすいTrail'), findsOneWidget);
    expect(find.text('Safe Trail Reflections'), findsNothing);
  });

  testWidgets('Arc input remains above the keyboard inset', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ArcScreen())),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      tester.getBottomRight(find.byType(TextField)).dy,
      lessThanOrEqualTo(400),
    );
  });

  testWidgets('Trail create sheet scrolls above the keyboard inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TrailScreen())),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Trailを残す'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final createTrailAction = find.text('Trailを残す').first;
    await tester.ensureVisible(createTrailAction);
    await tester.pumpAndSettle();
    await tester.tap(createTrailAction);
    await tester.pumpAndSettle();

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
