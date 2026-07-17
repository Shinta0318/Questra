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
import 'package:questra/features/settings/settings_screen.dart';
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
    'Settings': const SettingsScreen(),
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

  testWidgets('Home exposes only Arc, Mission, and active Quest sections', (
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

    expect(find.text('今日は何を叶えたい？'), findsOneWidget);
    expect(find.text('Arcに話す'), findsWidgets);
    expect(find.text('今日やるMission'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('進行中のQuest'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('進行中のQuest'), findsOneWidget);
    expect(find.text('最近のTrail'), findsNothing);
    expect(find.text('Guildの動き'), findsNothing);
    expect(find.text('Star Map'), findsNothing);
    expect(find.text('Horizon'), findsNothing);
  });

  testWidgets('Quest Detail focuses on progress and editable Missions', (
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
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(390, 2400);
    await tester.pump();

    expect(find.byTooltip('Questを編集'), findsOneWidget);
    expect(find.text('1 進捗'), findsOneWidget);
    expect(find.text('2 ArcのMissionプラン'), findsOneWidget);
    expect(find.text('Arcガイドを生成'), findsOneWidget);
    expect(find.text('3 Mission'), findsOneWidget);
    expect(find.textContaining('最初のMissionをつくる'), findsOneWidget);
    expect(find.text('Quest DNA Snapshot'), findsNothing);
    expect(find.text('Challenge Graph Preview'), findsNothing);
    expect(find.text('Quest支援の透明性'), findsNothing);
    expect(find.text('Dream Board'), findsNothing);
  });

  testWidgets('Settings exposes trust and privacy review surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );
    await tester.pump();

    expect(find.text('設定'), findsOneWidget);
    expect(find.text('Settings Map'), findsOneWidget);
    expect(find.text('Arcチュートリアル'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Trust & Privacy'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Trust & Privacy'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Quest / Mission / Trail'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Quest / Mission / Trail'), findsOneWidget);
    expect(find.text('Arc Memory'), findsWidgets);
    expect(find.text('Betaでは未接続'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Arc Memory管理プレビュー'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Arc Memory管理プレビュー'), findsOneWidget);
    expect(find.text('記憶を確認'), findsOneWidget);
    expect(find.text('記憶を削除'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('データリクエスト'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('データリクエスト'), findsOneWidget);
    expect(find.text('データエクスポート'), findsOneWidget);
    expect(find.text('データ削除リクエスト'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('目的別の同意'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('目的別の同意'), findsOneWidget);
    expect(find.text('Quest支援'), findsOneWidget);
    expect(find.text('プロダクト改善分析'), findsOneWidget);
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
