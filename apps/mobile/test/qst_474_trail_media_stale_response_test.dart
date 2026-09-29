import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/media/media_model.dart';
import 'package:questra/features/media/media_providers.dart';
import 'package:questra/features/media/media_repository.dart';
import 'package:questra/features/trail/trail_controller.dart';
import 'package:questra/features/trail/trail_model.dart';

void main() {
  test(
    'an in-flight media response cannot repopulate an empty Trail list',
    () async {
      final repository = _DelayedMediaRepository();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_AuthenticatedController.new),
          mediaRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(trailMediaControllerProvider.notifier);
      final trail = Trail(
        id: 'trail-a',
        questId: 'quest-a',
        missionId: 'mission-a',
        title: 'Trail',
        summary: '記録',
        content: '記録',
        trailType: TrailType.missionRecord,
      );

      final pending = controller.loadForTrails([trail]);
      await repository.requested.future;
      await controller.loadForTrails(const []);
      repository.complete(
        MediaAttachment(
          id: 'media-a',
          ownerId: 'owner-a',
          bucket: trailMediaBucket,
          path: 'owner-a/trail-a/a.png',
          mediaType: MediaType.image,
          relatedTable: 'trails',
          relatedId: 'trail-a',
        ),
      );
      await pending;

      expect(container.read(trailMediaControllerProvider), isEmpty);
    },
  );
}

class _AuthenticatedController extends AuthController {
  @override
  AuthState build() => const AuthState(
    profile: UserProfile(
      id: 'owner-a',
      email: 'owner-a@example.invalid',
      nickname: 'Navigator',
    ),
  );
}

class _DelayedMediaRepository extends InMemoryMediaRepository {
  final requested = Completer<void>();
  final _response = Completer<Map<String, MediaAttachment>>();

  @override
  Future<Map<String, MediaAttachment>> findTrailImageMap({
    required String ownerId,
    required List<String> trailIds,
  }) {
    if (!requested.isCompleted) requested.complete();
    return _response.future;
  }

  void complete(MediaAttachment attachment) {
    _response.complete({attachment.relatedId!: attachment});
  }
}
