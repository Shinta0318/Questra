import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/arc_quest_guide_service.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

void main() {
  test('local guide never replaces Gemini with fixed Missions', () async {
    const service = LocalArcQuestGuideService();
    final quest = Quest(
      title: 'シンガポールへ行く',
      description: '家族と食文化を楽しむ。予算は30万円。',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
      category: '旅行',
    );

    await expectLater(
      service.generate(quest: quest),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(contains('Gemini Planning API'), contains('入力内容は保持')),
        ),
      ),
    );
  });

  test('provider rate limit stays actionable on a non-2xx response', () {
    final message = planningFailureMessageFromException(
      const FunctionException(
        status: 503,
        details: {
          'status': 'retryable_error',
          'issues': [
            {'code': 'rate_limited'},
          ],
          'passes': [
            {
              'provider': {
                'error': {
                  'code': 'rate_limited',
                  'message': 'provider details must remain private',
                },
              },
            },
          ],
        },
      ),
    );
    expect(message, contains('Geminiの利用枠'));
    expect(message, contains('入力は残っています'));
    expect(message, isNot(contains('provider details')));
  });

  test('provider rate limit wait time is shown without provider details', () {
    final message = planningFailureMessageFromException(
      const FunctionException(
        status: 429,
        details: {
          'status': 'retryable_error',
          'retryAfterSeconds': 120,
          'issues': [
            {'code': 'rate_limited'},
          ],
          'passes': [
            {
              'provider': {
                'error': {
                  'code': 'rate_limited',
                  'message': 'private quota detail',
                },
              },
            },
          ],
        },
      ),
    );
    expect(message, contains('2分ほど待ってから'));
    expect(message, isNot(contains('private quota detail')));
  });

  test('grounding failure does not imply a route was created', () {
    expect(
      planningFailureMessage({
        'status': 'retryable_error',
        'issues': [
          {'code': 'grounding_failed'},
        ],
      }),
      contains('航路はまだ作成していません'),
    );
  });

  test('unrelated function errors are not mistaken for planning failures', () {
    expect(
      planningFailureMessageFromException(
        const FunctionException(
          status: 503,
          details: {'error': 'consent_check_unavailable'},
        ),
      ),
      isNull,
    );
  });
}
