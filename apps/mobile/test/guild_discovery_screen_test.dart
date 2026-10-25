import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/guild/guild_discovery_detail_screen.dart';
import 'package:questra/features/guild/guild_discovery_model.dart';
import 'package:questra/features/guild/guild_discovery_providers.dart';
import 'package:questra/features/guild/guild_discovery_repository.dart';
import 'package:questra/features/guild/guild_discovery_screen.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_model.dart';

void main() {
  testWidgets('shows an honest empty state without mock Quest cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guildPilotStatusProvider.overrideWith(
            (ref) async => const GuildPilotStatus(
              configured: true,
              enabled: true,
              cohort: 'widget-test',
            ),
          ),
          guildDiscoveryFeedProvider.overrideWith(
            (ref) async => const <GuildDiscoveryQuest>[],
          ),
        ],
        child: const MaterialApp(home: GuildDiscoveryScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('次の挑戦を見つける'), findsOneWidget);
    expect(find.text('おすすめを準備しています'), findsOneWidget);
    expect(find.byType(GuildDiscoveryDetailScreen), findsNothing);
  });

  testWidgets('offline preview exposes search without publishing or overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guildPilotStatusProvider.overrideWith(
            (ref) async =>
                const GuildPilotStatus(configured: false, enabled: true),
          ),
          guildDiscoveryFeedProvider.overrideWith(
            (ref) async => const <GuildDiscoveryQuest>[],
          ),
        ],
        child: const MaterialApp(home: GuildDiscoveryScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('guild-search')), findsOneWidget);
    expect(find.textContaining('オフラインプレビュー'), findsOneWidget);
    expect(find.text('自分のQuestを公開申請する'), findsNothing);
    final recommendedLabel = tester.getSize(find.text('おすすめ'));
    expect(recommendedLabel.height, lessThan(25));
    expect(recommendedLabel.width, greaterThan(50));
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens a public Quest detail with a recommendation reason', (
    tester,
  ) async {
    final quest = _quest();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guildPilotStatusProvider.overrideWith(
            (ref) async => const GuildPilotStatus(
              configured: true,
              enabled: true,
              cohort: 'widget-test',
            ),
          ),
          guildDiscoveryFeedProvider.overrideWith((ref) async => [quest]),
        ],
        child: const MaterialApp(home: GuildDiscoveryScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(quest.title));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(GuildDiscoveryDetailScreen), findsOneWidget);
    expect(find.text('見つかった理由'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('コピー機能を準備中'),
      260,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('コピー機能を準備中'), findsOneWidget);
  });

  testWidgets(
    'search filters the visible public feed and hides Mission-only tab',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            guildPilotStatusProvider.overrideWith(
              (ref) async =>
                  const GuildPilotStatus(configured: true, enabled: true),
            ),
            guildDiscoveryFeedProvider.overrideWith(
              (ref) async => [
                _quest(),
                GuildDiscoveryQuest(
                  id: 'publication-2',
                  title: '英語を学ぶ',
                  summary: '英語学習の航路',
                  authorDisplayName: 'Navigator',
                  tags: const ['学習'],
                  difficultyScore: 2,
                  visibility: GuildDiscoveryVisibility.public,
                  moderationStatus: GuildDiscoveryModerationStatus.approved,
                  publishedAt: DateTime.utc(2026, 7, 25),
                ),
              ],
            ),
          ],
          child: const MaterialApp(home: GuildDiscoveryScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Mission'), findsNothing);
      await tester.enterText(find.byKey(const Key('guild-search')), '英語');
      await tester.pump();
      expect(find.text('英語を学ぶ'), findsOneWidget);
      expect(find.text('富士山に登る'), findsNothing);
      await tester.enterText(find.byKey(const Key('guild-search')), '該当なし');
      await tester.pump();
      expect(find.text('一致する公開Questはありません'), findsOneWidget);
      await tester.ensureVisible(find.text('検索をクリア'));
      await tester.tap(find.text('検索をクリア'));
      await tester.pump();
      expect(find.text('富士山に登る'), findsOneWidget);
    },
  );

  testWidgets('detail stays readable at compact width and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        home: GuildDiscoveryDetailScreen(
          quest: _quest(),
          recommendationReason: '旅行の関心に近いQuestです',
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('publication requires an explicit content review', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _RecordingGuildRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guildPilotStatusProvider.overrideWith(
            (ref) async =>
                const GuildPilotStatus(configured: true, enabled: true),
          ),
          guildDiscoveryFeedProvider.overrideWith((ref) async => const []),
          guildDiscoveryRepositoryProvider.overrideWith((ref) => repository),
          questControllerProvider.overrideWith(_TestQuestController.new),
        ],
        child: const MaterialApp(home: GuildDiscoveryScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('自分のQuestを公開申請する'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Questの公開申請'), findsOneWidget);
    expect(find.text('審査へ提出する'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '審査へ提出する'))
          .onPressed,
      isNull,
    );
    expect(repository.publishedSummary, isNull);

    await tester.enterText(find.byType(TextField).last, '個人情報を含まない公開用の概要です。');
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -450),
    );
    await tester.pump();
    await tester.tap(find.text('公開する内容を確認しました'));
    await tester.pump();
    await tester.tap(find.text('審査へ提出する'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(repository.publishedSummary, '個人情報を含まない公開用の概要です。');
    expect(repository.publishedVisibility, GuildDiscoveryVisibility.public);
  });
}

class _TestQuestController extends QuestController {
  @override
  List<Quest> build() => [
    Quest(
      id: 'owned-quest',
      title: '自分のQuest',
      description: '非公開の説明',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
      category: '旅行',
    ),
  ];
}

class _RecordingGuildRepository implements GuildDiscoveryRepository {
  String? publishedSummary;
  GuildDiscoveryVisibility? publishedVisibility;

  @override
  Future<String> publishQuest({
    required String questId,
    required String summary,
    required List<String> tags,
    required GuildDiscoveryVisibility visibility,
    bool seekingCompanions = false,
  }) async {
    publishedSummary = summary;
    publishedVisibility = visibility;
    return 'publication-1';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GuildDiscoveryQuest _quest() {
  return GuildDiscoveryQuest(
    id: 'publication-1',
    title: '富士山に登る',
    summary: '安全な準備から山頂までをたどる公開航路です。',
    authorDisplayName: 'Hikari',
    tags: const ['旅行', '登山'],
    difficultyScore: 4,
    estimatedDurationDays: 90,
    copyCount: 12,
    completionCount: 4,
    visibility: GuildDiscoveryVisibility.public,
    moderationStatus: GuildDiscoveryModerationStatus.approved,
    publishedAt: DateTime.utc(2026, 7, 25),
  );
}
