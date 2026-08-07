import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/business_foundation/business_quest_dna.dart';
import 'package:questra/features/business_foundation/mission_support_profile.dart';
import 'package:questra/features/business_foundation/privacy_safe_segment_service.dart';
import 'package:questra/features/business_foundation/quest_contribution_service.dart';
import 'package:questra/features/business_foundation/quest_lifecycle_stage.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';

void main() {
  Quest quest({QuestStatus status = QuestStatus.active, double progress = 0}) =>
      Quest(
        id: '11111111-1111-4111-8111-111111111111',
        title: 'シンガポールへ行く',
        description: '来年の春に訪れる',
        difficulty: QuestDifficulty.normal,
        status: status,
        visibility: QuestVisibility.private,
        progress: progress,
      );

  Mission mission({required MissionStatus status}) => Mission(
    id: '22222222-2222-4222-8222-222222222222',
    questId: '11111111-1111-4111-8111-111111111111',
    questTitle: 'シンガポールへ行く',
    title: '渡航条件を公式情報で確認する',
    description: '確認結果を記録したら完了です',
    guideType: GuideType.knowledge,
    difficulty: MissionDifficulty.normal,
    status: status,
  );

  test('lifecycle infers progress but never abandons from inactivity', () {
    const service = QuestLifecycleStageService();
    expect(
      service.infer(quest(), const []).stage,
      QuestLifecycleStage.dreaming,
    );
    expect(
      service.infer(quest(), [mission(status: MissionStatus.completed)]).stage,
      QuestLifecycleStage.nearCompletion,
    );
    expect(service.canAutoTransitionTo(QuestLifecycleStage.abandoned), isFalse);
    expect(service.canAutoTransitionTo(QuestLifecycleStage.paused), isFalse);
  });

  test('sensitive Quest cannot create a Business signal', () {
    const classifier = QuestSensitivityClassifier();
    const policy = BusinessQuestSignalPolicy();
    final sensitivity = classifier.classify('借金の悩みを解決したい');
    expect(sensitivity, BusinessSensitivity.prohibitedForBusiness);
    expect(
      policy.canGenerate(consentGranted: true, sensitivity: sensitivity),
      isFalse,
    );
    expect(
      policy.derive({'category': '旅行', 'title': 'private', 'chat': 'private'}),
      {'category': '旅行'},
    );
  });

  test('Mission support is opt-in and sponsorable defaults false', () {
    const classifier = MissionSupportClassifier();
    final travel = classifier.classify('航空券を比較して予約する');
    expect(travel.externalServiceNeeded, isTrue);
    expect(travel.sponsorable, isFalse);
    expect(travel.businessRecommendationsEnabled, isFalse);
    expect(
      classifier.classify('病気の治療先を探す').sensitivity,
      MissionSupportSensitivity.prohibited,
    );
  });

  test('view alone never counts as Quest contribution', () {
    const service = QuestContributionService();
    final viewed = SupportInteraction(
      id: 'i',
      questId: 'q',
      missionId: 'm',
      sourceType: 'business',
      type: SupportInteractionType.viewed,
      occurredAt: DateTime(2026),
      consentVersion: 1,
    );
    expect(
      service.mayMeasureBusinessContribution(
        interaction: viewed,
        consentGranted: true,
        sensitive: false,
      ),
      isFalse,
    );
    expect(
      service.associationConfidence(
        missionCompleted: false,
        userMarkedHelpful: true,
      ),
      0,
    );
  });

  test('segment requires k=10 and strips non-whitelisted dimensions', () {
    const service = PrivacySafeSegmentService();
    expect(
      service.publish(
        const SegmentCandidate(
          dimensions: {'quest_category': '旅行'},
          cohortSize: 9,
          sensitive: false,
        ),
      ),
      isNull,
    );
    expect(
      service.publish(
        const SegmentCandidate(
          dimensions: {'quest_category': '旅行', 'quest_title': 'private'},
          cohortSize: 10,
          sensitive: false,
        ),
      ),
      {
        'dimensions': {'quest_category': '旅行'},
        'cohort_size': 10,
      },
    );
    expect(
      service.publish(
        const SegmentCandidate(
          dimensions: {'quest_category': '健康'},
          cohortSize: 100,
          sensitive: true,
        ),
      ),
      isNull,
    );
  });

  test('migrations keep raw data private and enforce idempotency', () {
    final root = Directory.current.parent.parent.path;
    final eventSql = File(
      '$root/supabase/migrations/202608010012_progress_intelligence_events.sql',
    ).readAsStringSync();
    final segmentSql = File(
      '$root/supabase/migrations/202608010018_privacy_safe_segments.sql',
    ).readAsStringSync();
    expect(eventSql, contains('unique (user_id, idempotency_key)'));
    expect(eventSql, contains('revoke insert, update, delete'));
    expect(
      eventSql,
      contains(
        'Free-form Quest, Mission, Arc chat, and Arc Memory text are prohibited',
      ),
    );
    expect(segmentSql, contains('minimum_cohort_size >= 10'));
    expect(segmentSql, contains('Client access is intentionally absent'));
  });
}
