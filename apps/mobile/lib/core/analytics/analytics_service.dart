import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics_event.dart';
import 'analytics_repository.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return LocalSafeAnalyticsRepository();
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(ref.watch(analyticsRepositoryProvider));
});

class AnalyticsService {
  const AnalyticsService(this._repository);

  final AnalyticsRepository _repository;

  Future<void> track(AnalyticsEvent event) {
    return _repository.record(event);
  }

  Future<void> questCreated({
    String? userId,
    required String category,
    required String difficulty,
    required String visibility,
  }) {
    return track(
      AnalyticsEvent(
        name: AnalyticsEventName.questCreated,
        userId: userId,
        properties: {
          'category': category,
          'difficulty': difficulty,
          'visibility': visibility,
        },
      ),
    );
  }

  Future<void> missionCompleted({
    String? userId,
    required String difficulty,
    required bool hasQuest,
  }) {
    return track(
      AnalyticsEvent(
        name: AnalyticsEventName.missionCompleted,
        userId: userId,
        properties: {'difficulty': difficulty, 'has_quest': hasQuest},
      ),
    );
  }

  Future<void> trailPosted({
    String? userId,
    required String surface,
    required bool hasQuest,
    required bool hasMission,
  }) {
    return track(
      AnalyticsEvent(
        name: AnalyticsEventName.trailPosted,
        userId: userId,
        properties: {
          'surface': surface,
          'has_quest': hasQuest,
          'has_mission': hasMission,
        },
      ),
    );
  }

  Future<void> arcChatSent({
    String? userId,
    required bool hasQuest,
    required bool hasTrail,
  }) {
    return track(
      AnalyticsEvent(
        name: AnalyticsEventName.arcChatSent,
        userId: userId,
        properties: {'has_quest': hasQuest, 'has_trail': hasTrail},
      ),
    );
  }

  Future<void> guildDraftCreated({String? userId, required String source}) {
    return track(
      AnalyticsEvent(
        name: AnalyticsEventName.guildDraftCreated,
        userId: userId,
        properties: {'source': source},
      ),
    );
  }

  Future<void> mediaAttached({
    String? userId,
    required String mediaType,
    required String surface,
  }) {
    return track(
      AnalyticsEvent(
        name: AnalyticsEventName.mediaAttached,
        userId: userId,
        properties: {'media_type': mediaType, 'surface': surface},
      ),
    );
  }

  Future<void> onboardingCompleted({
    String? userId,
    required String questInterest,
    required String signalFrequency,
  }) {
    return track(
      AnalyticsEvent(
        name: AnalyticsEventName.onboardingCompleted,
        userId: userId,
        properties: {
          'quest_interest': questInterest,
          'signal_frequency': signalFrequency,
        },
      ),
    );
  }
}
