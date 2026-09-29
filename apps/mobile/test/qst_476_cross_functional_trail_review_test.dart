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
import 'package:questra/features/trail/trail_providers.dart';
import 'package:questra/features/trail/trail_repository.dart';

void main() {
  test(
    'local Trail creation does not move the remote pagination cursor',
    () async {
      final repository = _RecordingTrailRepository();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_MutableAuthController.new),
          trailRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final auth =
          container.read(authControllerProvider.notifier)
              as _MutableAuthController;
      final controller = container.read(trailControllerProvider.notifier);
      auth.setOwner('owner-a');
      await controller.loadForUser('owner-a');
      repository.cursors.clear();

      controller.addManualTrail(
        title: '今日の記録',
        summary: '一歩進んだ',
        content: '候補日を確認した',
      );
      await Future<void>.delayed(Duration.zero);
      await controller.loadMoreForUser('owner-a');

      expect(repository.cursors.single?.id, 'trail-39');
    },
  );

  test(
    'delete failure after an owner switch never restores the old Trail',
    () async {
      final repository = _DelayedDeleteTrailRepository();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_OwnerAAuthController.new),
          trailControllerProvider.overrideWith(_TrailFixture.new),
          trailRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(trailControllerProvider.notifier);
      final auth =
          container.read(authControllerProvider.notifier)
              as _MutableAuthController;

      final pending = controller.removeTrailAndWait('trail-a');
      await repository.requested.future;
      auth.setOwner('owner-b');
      repository.fail();

      expect(await pending, isFalse);
      expect(container.read(trailControllerProvider), isEmpty);
    },
  );

  test(
    'a stale media batch cannot overwrite a newer local attachment',
    () async {
      final repository = _DelayedMediaRepository();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_OwnerAAuthController.new),
          mediaRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(trailMediaControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      final pending = controller.loadForTrails([_trail('trail-a', 0)]);
      await repository.requested.future;
      final replacement = _attachment('new-media');
      controller.setAttachment('trail-a', replacement);
      repository.complete(_attachment('old-media'));
      await pending;

      expect(
        container.read(trailMediaControllerProvider)['trail-a']?.id,
        'new-media',
      );
    },
  );
}

class _MutableAuthController extends AuthController {
  @override
  AuthState build() => const AuthState();

  void setOwner(String id) {
    state = AuthState(
      profile: UserProfile(id: id, email: '$id@example.invalid', nickname: id),
    );
  }
}

class _OwnerAAuthController extends _MutableAuthController {
  @override
  AuthState build() => const AuthState(
    profile: UserProfile(
      id: 'owner-a',
      email: 'owner-a@example.invalid',
      nickname: 'Owner A',
    ),
  );
}

class _TrailFixture extends TrailController {
  @override
  List<Trail> build() => [_trail('trail-a', 0)];
}

class _RecordingTrailRepository extends InMemoryTrailRepository {
  final cursors = <TrailPageCursor?>[];

  @override
  Future<List<Trail>> findByUser(
    String userId, {
    int limit = 40,
    TrailPageCursor? before,
  }) async {
    cursors.add(before);
    if (before != null) return const [];
    return List.generate(41, (index) => _trail('trail-$index', index));
  }
}

class _DelayedDeleteTrailRepository extends InMemoryTrailRepository {
  final requested = Completer<void>();
  final _result = Completer<void>();

  @override
  Future<void> delete({required String ownerId, required String trailId}) {
    if (!requested.isCompleted) requested.complete();
    return _result.future;
  }

  void fail() => _result.completeError(StateError('delete failed'));
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

Trail _trail(String id, int minute) => Trail(
  id: id,
  questId: 'quest-a',
  missionId: 'mission-a',
  title: id,
  summary: id,
  content: id,
  trailType: TrailType.missionRecord,
  createdAt: DateTime.utc(2026, 9, 1, 0, minute),
);

MediaAttachment _attachment(String id) => MediaAttachment(
  id: id,
  ownerId: 'owner-a',
  bucket: trailMediaBucket,
  path: 'owner-a/trail-a/$id.png',
  mediaType: MediaType.image,
  relatedTable: 'trails',
  relatedId: 'trail-a',
);
