import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/trail/trail_controller.dart';
import 'package:questra/features/trail/trail_draft_repository.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/features/trail/trail_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ja_JP'));

  test('Trail drafts are owner-scoped and expire fail-closed', () async {
    var now = DateTime.utc(2026, 9, 20);
    final repository = InMemoryTrailDraftRepository(clock: () => now);
    final draft = _draft(updatedAt: now);

    await repository.save('owner-a', draft);
    expect(await repository.load('owner-a'), same(draft));
    expect(await repository.load('owner-b'), isNull);

    now = now.add(const Duration(days: 8));
    expect(await repository.load('owner-a'), isNull);
  });

  testWidgets('Trail composer restores and clears an approved owner draft', (
    tester,
  ) async {
    final repository = InMemoryTrailDraftRepository();
    await repository.save('owner-a', _draft(updatedAt: DateTime.now()));
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_AuthenticatedController.new),
        questControllerProvider.overrideWith(_QuestFixture.new),
        missionControllerProvider.overrideWith(_MissionFixture.new),
        trailControllerProvider.overrideWith(_TrailFixture.new),
        trailDraftRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TrailScreen()),
      ),
    );
    await _pumpUi(tester);
    await tester.tap(find.byKey(const ValueKey('trail-primary-create')));
    await _pumpUi(tester);

    expect(find.text('保存中の下書きを復元しました。'), findsOneWidget);
    final note = tester.widget<TextFormField>(
      find.byKey(const ValueKey('trail-quick-note')),
    );
    expect(note.controller?.text, '航空券の候補日を家族と相談した');
    final quest = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('trail-quest-selector')),
    );
    final mission = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('trail-mission-selector-quest-a')),
    );
    expect(quest.initialValue, 'quest-a');
    expect(mission.initialValue, 'mission-a');

    final saveButton = find.widgetWithText(FilledButton, 'Trailを保存');
    await tester.ensureVisible(saveButton);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(saveButton);
    await _pumpUi(tester);

    expect(await repository.load('owner-a'), isNull);
    expect(container.read(trailControllerProvider), hasLength(1));
  });
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

TrailComposerDraft _draft({required DateTime updatedAt}) => TrailComposerDraft(
  id: 'draft-a',
  questId: 'quest-a',
  missionId: 'mission-a',
  title: '',
  summary: '航空券の候補日を家族と相談した',
  content: '',
  showDetails: false,
  updatedAt: updatedAt,
);

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
  List<Mission> build() => [
    Mission(
      id: 'mission-a',
      questId: 'quest-a',
      questTitle: 'シンガポールへ行く',
      title: '旅行日程を決める',
      description: '候補月を決める',
      guideType: GuideType.route,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.todo,
    ),
  ];
}

class _TrailFixture extends TrailController {
  @override
  List<Trail> build() => const [];
}
