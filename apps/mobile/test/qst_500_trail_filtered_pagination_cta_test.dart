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
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/features/trail/trail_pagination_state.dart';
import 'package:questra/features/trail/trail_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ja_JP'));

  testWidgets(
    'filtered empty state places older Trail action with its explanation',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_AuthFixture.new),
          questControllerProvider.overrideWith(_QuestFixture.new),
          missionControllerProvider.overrideWith(_MissionFixture.new),
          trailControllerProvider.overrideWith(_TrailFixture.new),
          trailPaginationControllerProvider.overrideWith(
            _PaginationFixture.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: TrailScreen(
              initialFilterQuestId: 'quest-empty',
              initialFilterMissionId: 'mission-empty',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final explanation = find.text('過去のTrailを読み込むと見つかる可能性があります。');
      final loadMore = find.byKey(const ValueKey('trail-load-more'));
      final clear = find.text('すべてのTrailを見る');
      expect(explanation, findsOneWidget);
      expect(loadMore, findsOneWidget);
      expect(clear, findsOneWidget);
      expect(
        tester.getTopLeft(explanation).dy,
        lessThan(tester.getTopLeft(loadMore).dy),
      );
      expect(
        tester.getTopLeft(loadMore).dy,
        lessThan(tester.getTopLeft(clear).dy),
      );
    },
  );
}

class _AuthFixture extends AuthController {
  @override
  AuthState build() => const AuthState(
    profile: UserProfile(
      id: 'owner-a',
      email: 'owner-a@example.invalid',
      nickname: 'Navigator',
    ),
  );
}

class _PaginationFixture extends TrailPaginationController {
  @override
  TrailPaginationState build() => const TrailPaginationState(hasMore: true);
}

class _QuestFixture extends QuestController {
  @override
  List<Quest> build() => [
    _quest('quest-empty', 'シンガポールへ行く'),
    _quest('quest-other', '英語を学ぶ'),
  ];
}

class _MissionFixture extends MissionController {
  @override
  List<Mission> build() => [
    _mission('mission-empty', 'quest-empty', 'シンガポールへ行く', '旅行日程を決める'),
    _mission('mission-other', 'quest-other', '英語を学ぶ', '英会話を練習する'),
  ];
}

class _TrailFixture extends TrailController {
  @override
  List<Trail> build() => [
    Trail(
      id: 'trail-other',
      questId: 'quest-other',
      missionId: 'mission-other',
      title: '英会話を練習した',
      summary: '練習記録',
      content: '10分話した',
      trailType: TrailType.missionRecord,
    ),
  ];
}

Quest _quest(String id, String title) => Quest(
  id: id,
  title: title,
  description: title,
  difficulty: QuestDifficulty.normal,
  status: QuestStatus.active,
  visibility: QuestVisibility.private,
);

Mission _mission(String id, String questId, String questTitle, String title) =>
    Mission(
      id: id,
      questId: questId,
      questTitle: questTitle,
      title: title,
      description: title,
      guideType: GuideType.route,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.todo,
    );
