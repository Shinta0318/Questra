import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/mission/mission_providers.dart';
import 'package:questra/features/mission/mission_repository.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/quest/quest_providers.dart';
import 'package:questra/features/quest/quest_repository.dart';
import 'package:questra/features/trail/trail_controller.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/features/trail/trail_providers.dart';
import 'package:questra/features/trail/trail_repository.dart';

void main() {
  test(
    'anonymous and fresh beta accounts start without journey content',
    () async {
      final container = _createContainer();
      addTearDown(container.dispose);

      expect(container.read(questControllerProvider), isEmpty);
      expect(container.read(missionControllerProvider), isEmpty);
      expect(container.read(trailControllerProvider), isEmpty);

      await container
          .read(authControllerProvider.notifier)
          .signUp(
            email: 'fresh@example.com',
            password: 'password',
            nickname: 'Fresh Navigator',
          );
      await _settleProviders();

      expect(container.read(questControllerProvider), isEmpty);
      expect(container.read(missionControllerProvider), isEmpty);
      expect(container.read(trailControllerProvider), isEmpty);
    },
  );

  test(
    'journey state is loaded for its owner and cleared on account change',
    () async {
      final questRepository = InMemoryQuestRepository();
      final missionRepository = InMemoryMissionRepository();
      final trailRepository = InMemoryTrailRepository();
      final container = _createContainer(
        questRepository: questRepository,
        missionRepository: missionRepository,
        trailRepository: trailRepository,
      );
      addTearDown(container.dispose);

      await container
          .read(authControllerProvider.notifier)
          .signUp(
            email: 'owner-a@example.com',
            password: 'password',
            nickname: 'Navigator A',
            loginId: 'owner-a',
          );
      await container
          .read(authControllerProvider.notifier)
          .login(identifier: 'owner-a', password: 'password');
      final ownerId = container.read(authControllerProvider).profile!.id;
      final quest = Quest(
        title: '自分の最初のQuest',
        description: '所有者境界を確認する',
        difficulty: QuestDifficulty.normal,
        status: QuestStatus.active,
        visibility: QuestVisibility.private,
      );
      final mission = Mission(
        questId: quest.id,
        questTitle: quest.title,
        title: '最初のMission',
        description: '小さな一歩を試す',
        guideType: GuideType.route,
        difficulty: MissionDifficulty.easy,
        status: MissionStatus.todo,
      );
      final trail = Trail(
        questId: quest.id,
        missionId: mission.id,
        title: '最初のTrail',
        summary: '一歩を記録した',
        content: '所有者本人にだけ見える記録',
        trailType: TrailType.missionRecord,
      );
      await questRepository.save(ownerId: ownerId, quest: quest);
      await missionRepository.save(mission);
      await trailRepository.save(ownerId: ownerId, trail: trail);

      container.read(questControllerProvider);
      container.read(missionControllerProvider);
      container.read(trailControllerProvider);
      await _settleProviders();

      expect(container.read(questControllerProvider).single.title, quest.title);
      expect(
        container.read(missionControllerProvider).single.title,
        mission.title,
      );
      expect(container.read(trailControllerProvider).single.title, trail.title);

      await container.read(authControllerProvider.notifier).logout();

      expect(container.read(questControllerProvider), isEmpty);
      expect(container.read(missionControllerProvider), isEmpty);
      expect(container.read(trailControllerProvider), isEmpty);

      await container
          .read(authControllerProvider.notifier)
          .signUp(
            email: 'owner-b@example.com',
            password: 'password',
            nickname: 'Navigator B',
            loginId: 'owner-b',
          );
      await container
          .read(authControllerProvider.notifier)
          .login(identifier: 'owner-b', password: 'password');
      await _settleProviders();

      expect(container.read(questControllerProvider), isEmpty);
      expect(container.read(missionControllerProvider), isEmpty);
      expect(container.read(trailControllerProvider), isEmpty);
    },
  );
}

ProviderContainer _createContainer({
  QuestRepository? questRepository,
  MissionRepository? missionRepository,
  TrailRepository? trailRepository,
}) {
  return ProviderContainer(
    overrides: [
      if (questRepository != null)
        questRepositoryProvider.overrideWithValue(questRepository),
      if (missionRepository != null)
        missionRepositoryProvider.overrideWithValue(missionRepository),
      if (trailRepository != null)
        trailRepositoryProvider.overrideWithValue(trailRepository),
    ],
  );
}

Future<void> _settleProviders() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
