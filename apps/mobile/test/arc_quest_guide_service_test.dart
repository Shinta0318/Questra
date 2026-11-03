import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:questra/features/quest/arc_quest_guide_service.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/planning_context.dart';
import 'package:questra/features/quest/planning_attempt_repository.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show FunctionException, SupabaseClient;

void main() {
  final approvalCandidate = ArcMissionCandidate(
    title: '旅行日程を決める',
    description: '同行者と候補日を確認する',
    planKey: 'm1',
    guideType: GuideType.route,
    difficulty: MissionDifficulty.normal,
  );
  final approvalGuide = ArcQuestGuide(
    questId: '00000000-0000-4000-8000-000000000001',
    summary: '旅行を実現する',
    path: '日程を決める',
    cautions: '',
    encouragement: '',
    sourceType: 'test',
    previewId: '00000000-0000-4000-8000-000000000002',
    approvalToken: '00000000-0000-4000-8000-000000000003',
    draftId: '00000000-0000-4000-8000-000000000004',
    missionCandidates: [approvalCandidate],
  );
  final rejectionGuide = ArcQuestGuide(
    questId: approvalGuide.questId,
    summary: approvalGuide.summary,
    path: approvalGuide.path,
    cautions: approvalGuide.cautions,
    encouragement: approvalGuide.encouragement,
    sourceType: approvalGuide.sourceType,
    previewId: approvalGuide.previewId,
    approvalToken: approvalGuide.approvalToken,
    planningAttemptFingerprint: List.filled(64, 'a').join(),
    planningAttemptKey: 'flutter-00000000-0000-4000-8000-000000000006',
    missionCandidates: [approvalCandidate],
  );

  test('rejecting a pending preview clears its local attempt', () async {
    final attempts = _RecordingAttempts();
    final requests = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test',
      httpClient: MockClient((request) async {
        requests.add(request.url.path);
        expect(jsonDecode(request.body)['mode'], 'reject');
        return http.Response(
          jsonEncode({'status': 'rejected'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    await SupabaseArcQuestGuideService(
      client: client,
      attemptRepository: attempts,
    ).reject(rejectionGuide);
    expect(requests, ['/functions/v1/quest-planning-v2']);
    expect(attempts.clears, 1);
  });

  test('failed rejection preserves the local attempt for retry', () async {
    final attempts = _RecordingAttempts();
    final client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({'error': 'preview_not_pending'}),
          409,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(client.dispose);
    await expectLater(
      SupabaseArcQuestGuideService(
        client: client,
        attemptRepository: attempts,
      ).reject(rejectionGuide),
      throwsA(isA<StateError>()),
    );
    expect(attempts.clears, 0);
  });

  test('failed approval never records candidate adoption', () async {
    final requests = <String>[];
    final attempts = _RecordingAttempts();
    final client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test',
      httpClient: MockClient((request) async {
        requests.add(request.url.path);
        return http.Response(
          jsonEncode({
            'status': 'conflict',
            'error': 'route_changed_since_preview',
          }),
          409,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    final service = SupabaseArcQuestGuideService(
      client: client,
      attemptRepository: attempts,
    );
    await expectLater(
      service.approve(guide: approvalGuide, candidates: [approvalCandidate]),
      throwsA(isA<StateError>()),
    );
    expect(requests, ['/functions/v1/quest-planning-v2']);
    expect(attempts.clears, 0);
  });

  test(
    'retryable approval storage failure keeps the reviewed candidates',
    () async {
      final requests = <String>[];
      final attempts = _RecordingAttempts();
      final client = SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test',
        httpClient: MockClient((request) async {
          requests.add(request.url.path);
          return http.Response(
            jsonEncode({
              'status': 'retryable_error',
              'error': 'approval_failed',
            }),
            503,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await expectLater(
        SupabaseArcQuestGuideService(
          client: client,
          attemptRepository: attempts,
        ).approve(guide: approvalGuide, candidates: [approvalCandidate]),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('保存できたか確認できません'),
          ),
        ),
      );
      expect(requests, ['/functions/v1/quest-planning-v2']);
      expect(attempts.clears, 0);
    },
  );

  test('legacy edited preview explains why approval cannot continue', () async {
    final requests = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test',
      httpClient: MockClient((request) async {
        requests.add(request.url.path);
        expect(jsonDecode(request.body)['approved_missions'], isA<List>());
        return http.Response(
          jsonEncode({'error': 'original_planning_wish_missing'}),
          409,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    await expectLater(
      SupabaseArcQuestGuideService(client: client).approve(
        guide: approvalGuide,
        candidates: [approvalCandidate.copyWith(title: '旅行日程を確定する')],
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('案を見送って'),
        ),
      ),
    );
    expect(requests, ['/functions/v1/quest-planning-v2']);
  });

  test('planning preference consent error keeps a clear recovery path', () {
    expect(
      planningApprovalFailureMessage(
        const FunctionException(
          status: 403,
          details: {'error': 'consent_required'},
        ),
      ),
      contains('航路案と入力は残っています'),
    );
    expect(
      planningFailureMessageFromException(
        const FunctionException(
          status: 403,
          details: {'error': 'planning_preferences_consent_required'},
        ),
      ),
      contains('計画設定'),
    );
    expect(
      planningApprovalFailureMessage(
        const FunctionException(
          status: 409,
          details: {'error': 'planning_context_changed'},
        ),
      ),
      contains('最新の条件'),
    );
    expect(
      planningFailureMessageFromException(
        const FunctionException(
          status: 400,
          details: {'error': 'invalid_planning_context'},
        ),
      ),
      contains('入力を短く'),
    );
  });

  test('edited approval conflict explains that another selection won', () {
    expect(
      planningApprovalFailureMessage(
        const FunctionException(
          status: 409,
          details: {
            'error': 'preview_already_approved_with_different_selection',
          },
        ),
      ),
      contains('先に確定'),
    );
  });

  test('unknown approval database failure does not imply a save', () {
    expect(
      planningApprovalFailureMessage(
        const FunctionException(
          status: 503,
          details: {'error': 'approval_failed'},
        ),
      ),
      contains('保存できたか確認できません'),
    );
  });

  test('candidate feedback follows a successful approval', () async {
    final requests = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test',
      httpClient: MockClient((request) async {
        requests.add(request.url.path);
        if (request.url.path == '/functions/v1/quest-planning-v2') {
          return http.Response(
            jsonEncode({'status': 'approved'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode('00000000-0000-4000-8000-000000000005'),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    final service = SupabaseArcQuestGuideService(client: client);
    await service.approve(
      guide: approvalGuide,
      candidates: [approvalCandidate],
    );
    expect(requests, [
      '/functions/v1/quest-planning-v2',
      '/rest/v1/rpc/record_mission_candidate_feedback',
    ]);
  });

  test(
    'changed planning attempt is recognized without exposing server details',
    () {
      expect(
        planningAttemptChanged(
          const FunctionException(
            status: 409,
            details: {'error': 'planning_attempt_changed'},
          ),
        ),
        true,
      );
      expect(
        planningAttemptChanged(
          const FunctionException(
            status: 503,
            details: {'error': 'planning_attempt_unavailable'},
          ),
        ),
        false,
      );
    },
  );

  test(
    'unchanged approval skips AI while edits, removal, and reorder do not',
    () {
      const first = ArcMissionCandidate(
        title: '旅行日程を決める',
        description: '同行者と日程を相談する',
        purpose: '同行者と日程を相談する',
        doneCondition: '候補日を決める',
        planKey: 'm1',
        guideType: GuideType.route,
        difficulty: MissionDifficulty.normal,
      );
      const second = ArcMissionCandidate(
        title: '予算を決める',
        description: '家族で予算を確認する',
        purpose: '家族で予算を確認する',
        doneCondition: '総額を決める',
        planKey: 'm2',
        guideType: GuideType.route,
        difficulty: MissionDifficulty.normal,
      );
      expect(approvalSelectionChanged([first, second], [first, second]), false);
      expect(
        approvalSelectionChanged(
          [first, second],
          [first.copyWith(title: '日程を確定する'), second],
        ),
        true,
      );
      expect(approvalSelectionChanged([first, second], [first]), true);
      expect(approvalSelectionChanged([first, second], [second, first]), true);
    },
  );

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
    await expectLater(
      service.approve(guide: approvalGuide, candidates: [approvalCandidate]),
      throwsA(isA<StateError>()),
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

  test('provider rate limit does not promise a quota reset time', () {
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
    expect(message, contains('回復時刻は確認できない'));
    expect(message, isNot(contains('2分ほど')));
    expect(message, isNot(contains('private quota detail')));
  });

  test('capped rate-limit wait does not promise recovery in one hour', () {
    final message = planningFailureMessage({
      'status': 'retryable_error',
      'retryAfterSeconds': 3600,
      'issues': [
        {'code': 'rate_limited'},
      ],
    });
    expect(message, contains('回復時刻は確認できない'));
    expect(message, isNot(contains('60分ほど')));
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

  test('rejected Mission quality explains why no route was saved', () {
    final message = planningFailureMessage({
      'status': 'manual_path',
      'issues': [
        {'code': 'critic_rejected'},
      ],
    });
    expect(message, contains('品質基準を満たしませんでした'));
    expect(message, contains('航路は保存していません'));
    expect(message, contains('Questの条件を見直して'));
  });

  test(
    'contradictory Critic response is retryable without blaming the Quest',
    () {
      const error = FunctionException(
        status: 503,
        details: {
          'status': 'retryable_error',
          'passes': [
            {
              'name': 'mission_critic',
              'provider': {
                'error': {'code': 'semantic_invalid'},
              },
            },
          ],
        },
      );
      expect(planningCriticEvaluationInvalid(error), isTrue);
      final message = planningFailureMessageFromException(error);
      expect(message, contains('評価結果を確認できませんでした'));
      expect(message, contains('航路は保存していません'));
      expect(message, isNot(contains('Questの条件を見直して')));
      expect(
        planningCriticEvaluationInvalid(
          const FunctionException(
            status: 503,
            details: {'status': 'retryable_error'},
          ),
        ),
        isFalse,
      );
    },
  );

  test('server length rejection remains actionable for older clients', () {
    expect(
      planningFailureMessageFromException(
        const FunctionException(
          status: 400,
          details: {'error': 'quest_wish_too_long'},
        ),
      ),
      contains('追加回答を短くしてください'),
    );
  });

  test('invalid target date asks for correction without implying a save', () {
    final message = planningFailureMessageFromException(
      const FunctionException(
        status: 400,
        details: {'error': 'invalid_target_date'},
      ),
    );
    expect(message, contains('希望達成日'));
    expect(message, contains('設定し直して'));
  });

  test('hosted execution limit never implies a route was saved', () {
    for (final status in [504, 546]) {
      final message = planningFailureMessageFromException(
        FunctionException(status: status),
      );
      expect(message, contains('途中で中断'));
      expect(message, contains('Questと入力は残っています'));
      expect(message, contains('手動で追加'));
    }
  });

  test('unconsented planning preferences never enter the AI request', () {
    const context = PlanningContext(
      weeklyMinutes: 120,
      budgetLabel: '2万円まで',
      location: '東京都',
      experience: '初心者',
      preferences: ['週末だけ'],
      setbackReasons: ['療養中'],
    );
    expect(planningContextPayload(context), isEmpty);
    final consented = planningContextPayload(
      context.copyWith(consentGranted: true),
    );
    expect(consented['budget'], '2万円まで');
    expect(consented['available_time'], {'weekly_minutes': 120});
    expect(consented['constraints'], ['週末だけ', '療養中']);
    expect(consented['approved_context'], isNotNull);
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

class _RecordingAttempts implements PlanningAttemptRepository {
  int clears = 0;

  @override
  Future<String> loadOrCreate(
    String? ownerId,
    String questId,
    String inputFingerprint,
  ) async => 'unused';

  @override
  Future<void> clear(
    String? ownerId,
    String questId,
    String inputFingerprint,
    String attemptKey,
  ) async {
    clears++;
  }
}
