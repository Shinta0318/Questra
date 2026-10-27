import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/safety/quest_safety_service.dart';
import 'package:questra/core/safety/safety_providers.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/quest/arc_quest_guide_controller.dart';
import 'package:questra/features/quest/arc_quest_guide_service.dart';
import 'package:questra/features/quest/planning_cooldown_repository.dart';
import 'package:questra/features/quest/planning_context.dart';
import 'package:questra/features/quest/planning_preferences.dart';
import 'package:questra/features/quest/planning_preferences_controller.dart';
import 'package:questra/features/quest/quest_model.dart';

class _PlanningPreferencesForTest extends PlanningPreferencesController {
  @override
  PlanningPreferences build() => const PlanningPreferences();
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
  }) async {
    throw StateError('利用条件の記録を確認できません。内容はAIへ送っていません。');
  }

  @override
  Future<void> approve({
    required ArcQuestGuide guide,
    required List<ArcMissionCandidate> candidates,
  }) async {}
}

class _RateLimitedGuide implements ArcQuestGuideService {
  int calls = 0;

  @override
  Future<ArcQuestGuide> generate({
    required Quest quest,
    PlanningContext? planningContext,
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
}

class _DelayedRateLimitedGuide extends _RateLimitedGuide {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<ArcQuestGuide> generate({
    required Quest quest,
    PlanningContext? planningContext,
  }) async {
    started.complete();
    await release.future;
    return super.generate(quest: quest, planningContext: planningContext);
  }
}

void main() {
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
