import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/trail/trail_controller.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/features/trail/trail_providers.dart';
import 'package:questra/features/trail/trail_repository.dart';

void main() {
  test('failed delete restores the Trail at its original position', () async {
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_AuthenticatedController.new),
        trailControllerProvider.overrideWith(_TrailFixture.new),
        trailRepositoryProvider.overrideWithValue(_FailingDeleteRepository()),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(trailControllerProvider.notifier);

    final deleted = await controller.removeTrailAndWait('trail-b');

    expect(deleted, isFalse);
    expect(container.read(trailControllerProvider).map((trail) => trail.id), [
      'trail-a',
      'trail-b',
      'trail-c',
    ]);
  });

  test('missing Trail is rejected without changing state', () async {
    final container = ProviderContainer(
      overrides: [trailControllerProvider.overrideWith(_TrailFixture.new)],
    );
    addTearDown(container.dispose);
    final controller = container.read(trailControllerProvider.notifier);

    expect(await controller.removeTrailAndWait('missing'), isFalse);
    expect(container.read(trailControllerProvider), hasLength(3));
  });
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

class _TrailFixture extends TrailController {
  @override
  List<Trail> build() => [
    _trail('trail-a'),
    _trail('trail-b'),
    _trail('trail-c'),
  ];
}

class _FailingDeleteRepository implements TrailRepository {
  @override
  Future<void> delete({required String ownerId, required String trailId}) {
    throw StateError('offline');
  }

  @override
  Future<List<Trail>> findByUser(
    String userId, {
    int limit = 40,
    TrailPageCursor? before,
  }) async => const [];

  @override
  Future<Trail> save({
    required String ownerId,
    required Trail trail,
    String visibility = 'private',
  }) async => trail;
}

Trail _trail(String id) => Trail(
  id: id,
  questId: 'quest-a',
  missionId: 'mission-a',
  title: id,
  summary: id,
  content: id,
  trailType: TrailType.missionRecord,
);
