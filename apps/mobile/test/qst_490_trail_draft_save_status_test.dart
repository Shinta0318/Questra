import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/trail/trail_controller.dart';
import 'package:questra/features/trail/trail_draft_repository.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/features/trail/trail_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ja_JP'));

  testWidgets('Trail composer discloses successful draft persistence', (
    tester,
  ) async {
    final repository = InMemoryTrailDraftRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    await _mount(tester, container);

    await tester.enterText(
      find.byKey(const ValueKey('trail-quick-note')),
      '旅行日程の候補を確認した',
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('下書きを保存しています...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('下書きを保存しました。'), findsOneWidget);
    expect((await repository.load('owner-a'))?.summary, '旅行日程の候補を確認した');
  });

  testWidgets('draft failure keeps input visible and reports recovery state', (
    tester,
  ) async {
    final container = _container(_FailingDraftRepository());
    addTearDown(container.dispose);
    await _mount(tester, container);

    await tester.enterText(
      find.byKey(const ValueKey('trail-quick-note')),
      '消えてはいけないTrail入力',
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('下書きを保存できません。入力は画面に残っています。'), findsOneWidget);
    final field = tester.widget<TextFormField>(
      find.byKey(const ValueKey('trail-quick-note')),
    );
    expect(field.controller?.text, '消えてはいけないTrail入力');
  });
}

ProviderContainer _container(TrailDraftRepository repository) =>
    ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_AuthenticatedController.new),
        questControllerProvider.overrideWith(_QuestFixture.new),
        missionControllerProvider.overrideWith(_MissionFixture.new),
        trailControllerProvider.overrideWith(_TrailFixture.new),
        trailDraftRepositoryProvider.overrideWithValue(repository),
      ],
    );

Future<void> _mount(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TrailScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(find.byKey(const ValueKey('trail-primary-create')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

class _FailingDraftRepository implements TrailDraftRepository {
  @override
  Future<void> clear(String ownerId) async {}

  @override
  Future<TrailComposerDraft?> load(String ownerId) async => null;

  @override
  Future<void> save(String ownerId, TrailComposerDraft draft) async =>
      throw StateError('offline');
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

class _QuestFixture extends QuestController {
  @override
  List<Quest> build() => [
    Quest(
      id: 'quest-a',
      title: 'シンガポールへ行く',
      description: '家族旅行を実現する',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
    ),
  ];
}

class _MissionFixture extends MissionController {
  @override
  List<Mission> build() => const [];
}

class _TrailFixture extends TrailController {
  @override
  List<Trail> build() => const [];
}
