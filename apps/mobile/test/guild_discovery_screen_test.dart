import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/guild/guild_discovery_detail_screen.dart';
import 'package:questra/features/guild/guild_discovery_model.dart';
import 'package:questra/features/guild/guild_discovery_providers.dart';
import 'package:questra/features/guild/guild_discovery_screen.dart';

void main() {
  testWidgets('shows an honest empty state without mock Quest cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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

  testWidgets('opens a public Quest detail with a recommendation reason', (
    tester,
  ) async {
    final quest = _quest();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guildDiscoveryFeedProvider.overrideWith((ref) async => [quest]),
        ],
        child: const MaterialApp(home: GuildDiscoveryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(quest.title));
    await tester.pumpAndSettle();

    expect(find.byType(GuildDiscoveryDetailScreen), findsOneWidget);
    expect(find.text('見つかった理由'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('コピー機能を準備中'),
      260,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('コピー機能を準備中'), findsOneWidget);
  });

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
