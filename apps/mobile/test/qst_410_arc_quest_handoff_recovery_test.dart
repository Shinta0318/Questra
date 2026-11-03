import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:questra/features/arc/arc_screen.dart';
import 'package:questra/features/arc/arc_chat_service.dart';
import 'package:questra/features/arc/arc_guidance_providers.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/quest/arc_quest_guide_controller.dart';
import 'package:questra/features/quest/arc_quest_guide_service.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/quest/quest_providers.dart';
import 'package:questra/features/quest/quest_repository.dart';
import 'package:questra/features/quest/planning_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets(
    'Quest save failure stops route planning and creates no missions',
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
            path: '/quest',
            builder: (_, _) => const Text(
              'Quest一覧',
              textDirection: TextDirection.ltr,
            ),
          ),
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

      final generate = find.widgetWithText(FilledButton, 'Questを保存して航路を描く');
      await tester.ensureVisible(generate);
      await tester.tap(generate);
      await tester.pump();
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 200));
        if (router.routeInformationProvider.value.uri.path != '/') break;
      }

      expect(container.read(questControllerProvider), hasLength(1));
      expect(container.read(questControllerProvider).single.title, isNot(wish));
      expect(container.read(missionControllerProvider), isEmpty);
      expect(router.routeInformationProvider.value.uri.path, '/quest');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Arc invokes planning only after the Quest is persisted', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = InMemoryQuestRepository();
    final guideService = _SaveOrderGuideService(repository);
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_SignedInAuthController.new),
        questRepositoryProvider.overrideWithValue(repository),
        arcQuestGuideServiceProvider.overrideWithValue(guideService),
      ],
    );
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

    await tester.enterText(
      find.byKey(const ValueKey('arc-chat-input')),
      '2028年10月までにシンガポールへ一人で旅行したい',
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
    final proceed = find.widgetWithText(FilledButton, 'このQuestで進む');
    await tester.ensureVisible(proceed);
    await tester.tap(proceed);
    await tester.pump();
    final generate = find.widgetWithText(FilledButton, 'Questを保存して航路を描く');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    for (var frame = 0; frame < 30 && !guideService.called; frame++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(guideService.called, isTrue);
    expect(guideService.questWasPersisted, isTrue);
    expect(container.read(questControllerProvider), hasLength(1));
    expect(container.read(missionControllerProvider), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long planning input is editable before saving a Quest', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const ArcScreen()),
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

    final wish = '2028年10月までにシンガポールへ一人で旅行したい。'
        '${'現地の文化を体験したい。' * 60}';
    await tester.enterText(find.byKey(const ValueKey('arc-chat-input')), wish);
    await tester.tap(find.byTooltip('メッセージを送信'));
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final start = find.widgetWithText(FilledButton, 'Questとして始める');
    await tester.ensureVisible(start.first);
    await tester.tap(start.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final proceed = find.widgetWithText(FilledButton, 'このQuestで進む');
    await tester.ensureVisible(proceed);
    await tester.tap(proceed);
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('arc-quest-motivation-field')),
      '旅行の理由を考える。' * 20,
    );
    await tester.enterText(
      find.byKey(const Key('arc-quest-success-condition-field')),
      '食文化を楽しんで帰国する。' * 20,
    );
    final generate = find.widgetWithText(FilledButton, 'Questを保存して航路を描く');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pump();

    final quests = container.read(questControllerProvider);
    expect(
      quests,
      isEmpty,
      reason: 'Saved Quest description length: '
          '${quests.isEmpty ? 0 : quests.single.description.length}',
    );
    expect(find.textContaining('航路に送る文章が長すぎます'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arc summary does not discard the original travel conditions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        arcChatServiceProvider.overrideWithValue(const _SummarizingArcChatService()),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const ArcScreen()),
        GoRoute(
          path: '/quest',
          builder: (_, _) => const Text('Quest一覧', textDirection: TextDirection.ltr),
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

    const wish = '2028年10月に家族でシンガポールへ行きたい。予算は20万円。食文化を重視し、ゆったり旅したい。';
    await tester.enterText(find.byKey(const ValueKey('arc-chat-input')), wish);
    await tester.tap(find.byTooltip('メッセージを送信'));
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final start = find.widgetWithText(FilledButton, 'Questとして始める');
    await tester.ensureVisible(start.first);
    await tester.tap(start.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final proceed = find.widgetWithText(FilledButton, 'このQuestで進む');
    await tester.ensureVisible(proceed);
    await tester.tap(proceed);
    await tester.pump();
    final generate = find.widgetWithText(FilledButton, 'Questを保存して航路を描く');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (container.read(questControllerProvider).isNotEmpty) break;
    }

    final quest = container.read(questControllerProvider).single;
    final description = quest.description;
    expect(description, contains('家族でシンガポール'));
    expect(description, contains('予算は20万円'));
    expect(description, contains('食文化を重視'));
    expect(description, contains('旅行を計画する'));
    final planningWish = planningWishWithAnswers(quest, const {});
    expect(planningWish, contains('予算は20万円'));
    expect(planningWish, contains('食文化を重視'));
    expect(container.read(missionControllerProvider), isEmpty);
    expect(tester.takeException(), isNull);
  });
}

class _SummarizingArcChatService implements ArcChatService {
  const _SummarizingArcChatService();

  @override
  Future<ArcChatResponse> send({
    required String userMessage,
    required List<ArcChatMessage> history,
    required ArcChatContext context,
  }) async {
    return ArcChatResponse(
      message: '旅行の希望を整理したよ。',
      sourceType: 'test_summary',
      intentType: ArcConversationIntent.questIntent,
      showQuestCta: true,
      questSuggestion: ArcQuestSuggestion(
        title: 'シンガポールへの家族旅行',
        description: '旅行を計画する',
        category: '旅行',
        difficulty: QuestDifficulty.normal,
        sourceInput: userMessage,
      ),
    );
  }
}

class _SignedInAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    profile: UserProfile(
      id: 'qst-410-user',
      email: 'qst410@example.invalid',
      nickname: 'Navigator',
      onboardingCompleted: true,
      legalAcceptanceCurrent: true,
    ),
  );
}

class _SaveOrderGuideService extends LocalArcQuestGuideService {
  _SaveOrderGuideService(this.repository);

  final InMemoryQuestRepository repository;
  bool called = false;
  bool questWasPersisted = false;

  @override
  Future<ArcQuestGuide> generate({
    required Quest quest,
    PlanningContext? planningContext,
    Map<String, String> clarificationAnswers = const {},
  }) async {
    called = true;
    final saved = await repository.findByUser('qst-410-user');
    questWasPersisted = saved.any((item) => item.id == quest.id);
    throw StateError('test-only planning failure');
  }
}
