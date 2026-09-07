import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/features/trail/trail_share_policy.dart';

void main() {
  final trail = Trail(
    title: '初めての登山練習',
    summary: '高尾山で歩き方を確認した。',
    content: '次は装備を見直す。',
    trailType: TrailType.missionRecord,
  );
  final now = DateTime.utc(2026, 8, 25, 12);

  test('allows a bounded selected-field snapshot', () {
    final review = const TrailSharePolicy().review(
      TrailShareDraft(
        trail: trail,
        fields: {TrailShareField.title, TrailShareField.summary},
        expiresAt: now.add(const Duration(days: 7)),
      ),
      now: now,
    );
    expect(review.isSafe, isTrue);
  });

  test('rejects contact details, empty fields, and excessive lifetime', () {
    final policy = const TrailSharePolicy();
    expect(
      policy.review(
        TrailShareDraft(trail: trail, fields: {}, expiresAt: now.add(const Duration(days: 1))),
        now: now,
      ).isSafe,
      isFalse,
    );
    expect(
      policy.review(
        TrailShareDraft(
          trail: trail.copyWith(content: '連絡先は 090-1234-5678'),
          fields: {TrailShareField.content},
          expiresAt: now.add(const Duration(days: 1)),
        ),
        now: now,
      ).isSafe,
      isFalse,
    );
    expect(
      policy.review(
        TrailShareDraft(
          trail: trail,
          fields: {TrailShareField.title},
          expiresAt: now.add(const Duration(days: 31)),
        ),
        now: now,
      ).isSafe,
      isFalse,
    );
  });
}
