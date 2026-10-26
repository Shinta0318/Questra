import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/safety/quest_safety_service.dart';
import 'package:questra/core/safety/safety_providers.dart';
import 'package:questra/features/quest/arc_quest_guide_controller.dart';
import 'package:questra/features/quest/arc_quest_guide_service.dart';
import 'package:questra/features/quest/planning_context.dart';
import 'package:questra/features/quest/planning_preferences.dart';
import 'package:questra/features/quest/planning_preferences_controller.dart';
import 'package:questra/features/quest/quest_model.dart';

class _PlanningPreferencesForTest extends PlanningPreferencesController {
  @override
  PlanningPreferences build() => const PlanningPreferences();
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
}
