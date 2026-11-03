import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/safety/quest_safety_service.dart';
import 'package:questra/core/safety/safety_providers.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/arc_quest_guide_controller.dart';
import 'package:questra/features/quest/arc_quest_guide_service.dart';
import 'package:questra/features/quest/planning_cooldown_repository.dart';
import 'package:questra/features/quest/planning_context.dart';
import 'package:questra/features/quest/planning_preferences.dart';
import 'package:questra/features/quest/planning_preferences_controller.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_detail_screen.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/task/task_controller.dart';
import 'package:questra/features/task/task_load_state.dart';
import 'package:questra/features/task/task_model.dart';

class _PlanningPreferencesForTest extends PlanningPreferencesController {
  @override
  PlanningPreferences build() => const PlanningPreferences();
}

class _ConsentedPlanningPreferencesForTest
    extends PlanningPreferencesController {
  @override
  PlanningPreferences build() =>
      const PlanningPreferences(context: PlanningContext(consentGranted: true));
}

class _OwnerAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    profile: UserProfile(
      id: 'owner-a',
      email: 'owner-a@example.invalid',
      nickname: 'A',
    ),
  );
}

class _SwitchableAuthController extends _OwnerAuthController {
  void switchToOtherOwner() {
    state = const AuthState(
      profile: UserProfile(
        id: 'owner-b',
        email: 'owner-b@example.invalid',
        nickname: 'B',
      ),
    );
  }
}

class _ConsentDeniedGuide implements ArcQuestGuideService {
  @override
  Future<ArcQuestGuide> generate({
    required Quest quest,
    PlanningContext? planningContext,
    Map<String, String> clarificationAnswers = const {},
  }) async {
    throw StateError('利用条件の記録を確認できません。内容はAIへ送っていません。');
  }

  @override
  Future<void> approve({
    required ArcQuestGuide guide,
    required List<ArcMissionCandidate> candidates,
  }) async {}

  @override
  Future<void> reject(ArcQuestGuide guide) async {}
}

class _RateLimitedGuide implements ArcQuestGuideService {
  int calls = 0;

  @override
  Future<ArcQuestGuide> generate({
    required Quest quest,
    PlanningContext? planningContext,
    Map<String, String> clarificationAnswers = const {},
  }) async {
    calls++;
    throw const PlanningRateLimitException(
      'Geminiの利用枠に達しました。2分ほど待ってください。',
      Duration(minutes: 2),
    );
  }

  @override
  Future<void> approve({
    required ArcQuestGuide guide,
    required List<ArcMissionCandidate> candidates,
  }) async {}

  @override
  Future<void> reject(ArcQuestGuide guide) async {}
}

class _DelayedRateLimitedGuide extends _RateLimitedGuide {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<ArcQuestGuide> generate({
    required Quest quest,
    PlanningContext? planningContext,
    Map<String, String> clarificationAnswers = const {},
  }) async {
    started.complete();
    await release.future;
    return super.generate(quest: quest, planningContext: planningContext);
  }
}

class _ClarifyingGuide implements ArcQuestGuideService {
  int calls = 0;
  Map<String, String> receivedAnswers = const {};

  @override
  Future<ArcQuestGuide> generate({
    required Quest quest,
    PlanningContext? planningContext,
    Map<String, String> clarificationAnswers = const {},
  }) async {
    calls++;
    receivedAnswers = clarificationAnswers;
    if (calls == 1) {
      throw const PlanningClarificationException(['どこで英語を使いたい？']);
    }
    throw StateError('回答を受け取った後の合成エラー');
  }

  @override
  Future<void> approve({
    required ArcQuestGuide guide,
    required List<ArcMissionCandidate> candidates,
  }) async {}

  @override
  Future<void> reject(ArcQuestGuide guide) async {}
}

class _StaticQuestController extends QuestController {
  _StaticQuestController(this.quest);

  final Quest quest;

  @override
  List<Quest> build() => [quest];
}

class _PreloadedClarificationController extends ArcQuestGuideController {
  _PreloadedClarificationController(this.questId);

  final String questId;

  @override
  ArcQuestGuideState build() => ArcQuestGuideState(
    clarificationQuestionsByQuest: {
      questId: const ['どこで英語を使いたい？'],
    },
  );
}

class _PreloadedGuideController extends ArcQuestGuideController {
  _PreloadedGuideController(this.guide);

  final ArcQuestGuide guide;

  @override
  ArcQuestGuideState build() =>
      ArcQuestGuideState(guidesByQuest: {guide.questId: guide});
}

class _RejectableGuide extends LocalArcQuestGuideService {
  bool fail = false;
  int rejects = 0;

  @override
  Future<void> reject(ArcQuestGuide guide) async {
    rejects++;
    if (fail) throw StateError('航路案を見送れませんでした');
  }
}

class _PendingApprovalGuide extends LocalArcQuestGuideService {
  final Completer<void> pending = Completer<void>();
  int approvals = 0;

  @override
  Future<void> approve({
    required ArcQuestGuide guide,
    required List<ArcMissionCandidate> candidates,
  }) {
    approvals++;
    return pending.future;
  }
}

class _FailedApprovalGuide extends LocalArcQuestGuideService {
  @override
  Future<void> approve({
    required ArcQuestGuide guide,
    required List<ArcMissionCandidate> candidates,
  }) async {
    throw StateError('航路を保存できませんでした');
  }
}

class _FailedTaskReloadController extends TaskController {
  @override
  List<QuestraTask> build() => const [];

  @override
  Future<void> loadForQuestIds(List<String> questIds) async {
    ref.read(taskLoadStateProvider.notifier).failed();
  }
}

void main() {
  test('failed route approval retains its reviewable guide', () async {
    final quest = Quest(
      title: 'シンガポールへ行く',
      description: '旅行を計画する',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
    );
    final guide = ArcQuestGuide(
      questId: quest.id,
      summary: '旅行の準備',
      path: '日程を決める',
      cautions: '',
      encouragement: '',
      sourceType: 'test_preview',
      previewId: 'preview-id',
      approvalToken: 'approval-token',
      missionCandidates: const [
        ArcMissionCandidate(
          title: '旅行日程を決める',
          description: '同行者と休暇を確認して旅行日程を決める',
          guideType: GuideType.route,
          difficulty: MissionDifficulty.easy,
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_OwnerAuthController.new),
        arcQuestGuideControllerProvider.overrideWith(
          () => _PreloadedGuideController(guide),
        ),
        arcQuestGuideServiceProvider.overrideWithValue(_FailedApprovalGuide()),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(arcQuestGuideControllerProvider.notifier)
          .approveForQuest(quest, guide, guide.missionCandidates),
      throwsStateError,
    );
    expect(
      container.read(arcQuestGuideControllerProvider).guideFor(quest.id),
      same(guide),
    );
  });

  testWidgets('approval without a server preview never saves a Mission', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final quest = Quest(
      title: 'シンガポールへ行く',
      description: '旅行を計画する',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
    );
    final guide = ArcQuestGuide(
      questId: quest.id,
      summary: '旅行の準備',
      path: '日程を決める',
      cautions: '',
      encouragement: '',
      sourceType: 'legacy_preview',
      missionCandidates: const [
        ArcMissionCandidate(
          title: '旅行日程を決める',
          description: '同行者と休暇を確認して旅行日程を決める',
          guideType: GuideType.route,
          difficulty: MissionDifficulty.easy,
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        questControllerProvider.overrideWith(
          () => _StaticQuestController(quest),
        ),
        arcQuestGuideControllerProvider.overrideWith(
          () => _PreloadedGuideController(guide),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: QuestDetailScreen(questId: quest.id)),
      ),
    );
    await tester.pump();

    final confirm = find.widgetWithText(FilledButton, '1件のMissionを確定する');
    await tester.ensureVisible(confirm);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    expect(find.textContaining('承認情報を確認できません'), findsWidgets);
    expect(container.read(missionControllerProvider), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('route approval cannot be submitted twice while pending', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final quest = Quest(
      title: 'シンガポールへ行く',
      description: '旅行を計画する',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
    );
    final guide = ArcQuestGuide(
      questId: quest.id,
      summary: '旅行の準備',
      path: '日程を決める',
      cautions: '',
      encouragement: '',
      sourceType: 'test_preview',
      previewId: 'preview-id',
      approvalToken: 'approval-token',
      missionCandidates: const [
        ArcMissionCandidate(
          title: '旅行日程を決める',
          description: '同行者と休暇を確認して旅行日程を決める',
          guideType: GuideType.route,
          difficulty: MissionDifficulty.easy,
        ),
      ],
    );
    final service = _PendingApprovalGuide();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_OwnerAuthController.new),
        questControllerProvider.overrideWith(
          () => _StaticQuestController(quest),
        ),
        arcQuestGuideControllerProvider.overrideWith(
          () => _PreloadedGuideController(guide),
        ),
        arcQuestGuideServiceProvider.overrideWithValue(service),
        taskControllerProvider.overrideWith(_FailedTaskReloadController.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: QuestDetailScreen(questId: quest.id)),
      ),
    );
    await tester.pump();

    final confirm = find.widgetWithText(FilledButton, '1件のMissionを確定する');
    await tester.dragUntilVisible(
      confirm,
      find.byType(ListView).first,
      const Offset(0, -500),
    );
    await tester.pump();
    await tester.tap(confirm);
    await tester.pump();
    expect(service.approvals, 1);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.tap(confirm);
    await tester.pump();
    expect(service.approvals, 1);

    service.pending.complete();
    await tester.pump(const Duration(milliseconds: 100));
    expect(service.approvals, 1);
    expect(
      container.read(arcQuestGuideControllerProvider).guideFor(quest.id),
      isNull,
    );
    expect(find.textContaining('航路は保存されましたが、表示を更新できませんでした'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Quest route preview stays visible if rejection fails', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final quest = Quest(
      title: 'シンガポールへ行く',
      description: '旅行を計画する',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
    );
    final guide = ArcQuestGuide(
      questId: quest.id,
      summary: '旅行を実現する',
      path: '日程を決める',
      cautions: '',
      encouragement: '',
      sourceType: 'test',
      missionCandidates: const [],
    );
    final service = _RejectableGuide()..fail = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questControllerProvider.overrideWith(
            () => _StaticQuestController(quest),
          ),
          arcQuestGuideControllerProvider.overrideWith(
            () => _PreloadedGuideController(guide),
          ),
          arcQuestGuideServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(home: QuestDetailScreen(questId: quest.id)),
      ),
    );
    await tester.pump();
    final reject = find.widgetWithText(TextButton, 'この案を見送る');
    await tester.ensureVisible(reject);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(reject);
    await tester.pump();
    expect(service.rejects, 1);
    expect(reject, findsOneWidget);
    service.fail = false;
    await tester.ensureVisible(reject);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(reject);
    await tester.pump();
    expect(service.rejects, 2);
    expect(reject, findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('route rejection clears only a successfully rejected preview', () async {
    final quest = Quest(
      title: 'シンガポールへ行く',
      description: '旅行を計画する',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
    );
    final guide = ArcQuestGuide(
      questId: quest.id,
      summary: '旅行を実現する',
      path: '日程を決める',
      cautions: '',
      encouragement: '',
      sourceType: 'test',
      missionCandidates: const [],
    );
    final service = _RejectableGuide()..fail = true;
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_OwnerAuthController.new),
        arcQuestGuideControllerProvider.overrideWith(
          () => _PreloadedGuideController(guide),
        ),
        arcQuestGuideServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(arcQuestGuideControllerProvider.notifier);
    await expectLater(
      controller.rejectForQuest(quest, guide),
      throwsA(isA<StateError>()),
    );
    expect(
      container.read(arcQuestGuideControllerProvider).guideFor(quest.id),
      same(guide),
    );
    service.fail = false;
    await controller.rejectForQuest(quest, guide);
    expect(
      container.read(arcQuestGuideControllerProvider).guideFor(quest.id),
      isNull,
    );
    expect(service.rejects, 2);
  });

  testWidgets('Quest route questions need answers before resubmission', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final quest = Quest(
      title: '英語で自己紹介したい',
      description: '3か月後の交流会で話す',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
    );
    final service = _ClarifyingGuide();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questControllerProvider.overrideWith(
            () => _StaticQuestController(quest),
          ),
          arcQuestGuideControllerProvider.overrideWith(
            () => _PreloadedClarificationController(quest.id),
          ),
          questSafetyServiceProvider.overrideWithValue(
            const LocalQuestSafetyService(),
          ),
          planningPreferencesControllerProvider.overrideWith(
            _ConsentedPlanningPreferencesForTest.new,
          ),
          arcQuestGuideServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(home: QuestDetailScreen(questId: quest.id)),
      ),
    );
    await tester.pump();

    final field = find.byKey(
      ValueKey('route-clarification-${quest.id}-どこで英語を使いたい？'),
    );
    await tester.ensureVisible(field);
    final submit = find.widgetWithText(FilledButton, '回答して航路を描く');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.enterText(field, '職場の交流会');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    await tester.tap(submit);
    await tester.pump();
    expect(service.receivedAnswers, {'どこで英語を使いたい？': '職場の交流会'});
    expect(tester.takeException(), isNull);
  });

  test(
    'planning clarification keeps questions and forwards explicit answers',
    () async {
      final service = _ClarifyingGuide();
      final container = ProviderContainer(
        overrides: [
          questSafetyServiceProvider.overrideWithValue(
            const LocalQuestSafetyService(),
          ),
          planningPreferencesControllerProvider.overrideWith(
            _ConsentedPlanningPreferencesForTest.new,
          ),
          arcQuestGuideServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      final quest = Quest(
        title: '英語で自己紹介したい',
        description: '3か月後の交流会で話す',
        difficulty: QuestDifficulty.normal,
        status: QuestStatus.active,
        visibility: QuestVisibility.private,
      );

      await container
          .read(arcQuestGuideControllerProvider.notifier)
          .generateForQuest(quest);
      final clarification = container.read(arcQuestGuideControllerProvider);
      expect(clarification.clarificationQuestionsFor(quest.id), [
        'どこで英語を使いたい？',
      ]);
      expect(clarification.errorFor(quest.id), isNull);
      expect(clarification.isLoading(quest.id), isFalse);

      await container
          .read(arcQuestGuideControllerProvider.notifier)
          .generateForQuest(
            quest,
            clarificationAnswers: {'どこで英語を使いたい？': '職場の交流会'},
          );
      expect(service.receivedAnswers, {'どこで英語を使いたい？': '職場の交流会'});
      expect(service.calls, 2);
      expect(
        container.read(arcQuestGuideControllerProvider).guideFor(quest.id),
        isNull,
      );
    },
  );

  test(
    'clarification answers are added to the planning wish only when present',
    () {
      final quest = Quest(
        title: '英語で自己紹介したい',
        description: '3か月後の交流会で話す',
        difficulty: QuestDifficulty.normal,
        status: QuestStatus.active,
        visibility: QuestVisibility.private,
      );
      expect(
        planningWishWithAnswers(quest, const {}),
        '英語で自己紹介したい\n3か月後の交流会で話す',
      );
      expect(
        planningWishWithAnswers(quest, const {'どこで使う？': '職場の交流会'}),
        contains('どこで使う？ 職場の交流会'),
      );
    },
  );

  test('long clarification answers are rejected instead of truncated', () {
    final quest = Quest(
      title: '英語で自己紹介したい',
      description: '3か月後の交流会で話す',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
    );
    expect(
      () => planningWishWithAnswers(quest, {'どこで使う？': 'あ' * 1200}),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'clarification answers stop before AI without planning consent',
    () async {
      final service = _ClarifyingGuide();
      final container = ProviderContainer(
        overrides: [
          questSafetyServiceProvider.overrideWithValue(
            const LocalQuestSafetyService(),
          ),
          planningPreferencesControllerProvider.overrideWith(
            _PlanningPreferencesForTest.new,
          ),
          arcQuestGuideServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      final quest = Quest(
        title: '英語で自己紹介したい',
        description: '3か月後の交流会で話す',
        difficulty: QuestDifficulty.normal,
        status: QuestStatus.active,
        visibility: QuestVisibility.private,
      );

      await container
          .read(arcQuestGuideControllerProvider.notifier)
          .generateForQuest(
            quest,
            clarificationAnswers: {'どこで英語を使いたい？': '職場の交流会'},
          );
      final state = container.read(arcQuestGuideControllerProvider);
      expect(service.calls, 0);
      expect(state.errorFor(quest.id), contains('まだ送信していません'));
      expect(state.isLoading(quest.id), isFalse);
    },
  );

  test(
    'route errors show consent feedback without a technical prefix',
    () async {
      final container = ProviderContainer(
        overrides: [
          questSafetyServiceProvider.overrideWithValue(
            const LocalQuestSafetyService(),
          ),
          planningPreferencesControllerProvider.overrideWith(
            _PlanningPreferencesForTest.new,
          ),
          arcQuestGuideServiceProvider.overrideWithValue(_ConsentDeniedGuide()),
        ],
      );
      addTearDown(container.dispose);
      final quest = Quest(
        title: 'シンガポールへ行く',
        description: '旅行を計画する',
        difficulty: QuestDifficulty.normal,
        status: QuestStatus.active,
        visibility: QuestVisibility.private,
      );

      await container
          .read(arcQuestGuideControllerProvider.notifier)
          .generateForQuest(quest);

      final state = container.read(arcQuestGuideControllerProvider);
      expect(state.errorFor(quest.id), contains('AIへ送っていません'));
      expect(state.errorFor(quest.id), isNot(contains('Bad state')));
      expect(state.guideFor(quest.id), isNull);
      expect(state.isLoading(quest.id), isFalse);
    },
  );

  test(
    'rate-limited route retry is blocked until the suggested time',
    () async {
      final service = _RateLimitedGuide();
      final container = ProviderContainer(
        overrides: [
          questSafetyServiceProvider.overrideWithValue(
            const LocalQuestSafetyService(),
          ),
          planningPreferencesControllerProvider.overrideWith(
            _PlanningPreferencesForTest.new,
          ),
          arcQuestGuideServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      final quest = Quest(
        title: 'シンガポールへ行く',
        description: '旅行を計画する',
        difficulty: QuestDifficulty.normal,
        status: QuestStatus.active,
        visibility: QuestVisibility.private,
      );

      final controller = container.read(
        arcQuestGuideControllerProvider.notifier,
      );
      await controller.generateForQuest(quest);
      await controller.generateForQuest(quest);

      final state = container.read(arcQuestGuideControllerProvider);
      expect(service.calls, 1);
      expect(state.retryAfterFor(quest.id)!.isAfter(DateTime.now()), isTrue);
      expect(state.errorFor(quest.id), contains('2分'));
      expect(state.isLoading(quest.id), isFalse);
    },
  );

  test(
    'restored route cooldown prevents a provider call after restart',
    () async {
      final repository = InMemoryPlanningCooldownRepository();
      final service = _RateLimitedGuide();
      final quest = Quest(
        title: 'シンガポールへ行く',
        description: '旅行を計画する',
        difficulty: QuestDifficulty.normal,
        status: QuestStatus.active,
        visibility: QuestVisibility.private,
      );
      ProviderContainer container() => ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_OwnerAuthController.new),
          questSafetyServiceProvider.overrideWithValue(
            const LocalQuestSafetyService(),
          ),
          planningPreferencesControllerProvider.overrideWith(
            _PlanningPreferencesForTest.new,
          ),
          planningCooldownRepositoryProvider.overrideWithValue(repository),
          arcQuestGuideServiceProvider.overrideWithValue(service),
        ],
      );

      final first = container();
      await first
          .read(arcQuestGuideControllerProvider.notifier)
          .generateForQuest(quest);
      expect(service.calls, 1);
      first.dispose();

      final restarted = container();
      addTearDown(restarted.dispose);
      await restarted
          .read(arcQuestGuideControllerProvider.notifier)
          .generateForQuest(quest);
      expect(service.calls, 1);
      expect(
        restarted.read(arcQuestGuideControllerProvider).retryAfterFor(quest.id),
        isNotNull,
      );
    },
  );

  test(
    'old owner rate-limit result is discarded after account switch',
    () async {
      final repository = InMemoryPlanningCooldownRepository();
      final service = _DelayedRateLimitedGuide();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_SwitchableAuthController.new),
          questSafetyServiceProvider.overrideWithValue(
            const LocalQuestSafetyService(),
          ),
          planningPreferencesControllerProvider.overrideWith(
            _PlanningPreferencesForTest.new,
          ),
          planningCooldownRepositoryProvider.overrideWithValue(repository),
          arcQuestGuideServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      final quest = Quest(
        title: 'シンガポールへ行く',
        description: '旅行を計画する',
        difficulty: QuestDifficulty.normal,
        status: QuestStatus.active,
        visibility: QuestVisibility.private,
      );

      final pending = container
          .read(arcQuestGuideControllerProvider.notifier)
          .generateForQuest(quest);
      await service.started.future;
      final auth = container.read(authControllerProvider.notifier);
      (auth as _SwitchableAuthController).switchToOtherOwner();
      service.release.complete();
      await pending;

      final state = container.read(arcQuestGuideControllerProvider);
      expect(state.retryAfterFor(quest.id), isNull);
      expect(state.errorFor(quest.id), isNull);
      expect(await repository.load('owner-a', quest.id), isNull);
      expect(await repository.load('owner-b', quest.id), isNull);
    },
  );
}
