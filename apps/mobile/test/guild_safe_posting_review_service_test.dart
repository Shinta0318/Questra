import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/guild/guild_safe_posting_review_service.dart';

void main() {
  const service = GuildSafePostingReviewService();

  test('blocks direct contact information', () {
    final review = service.review(
      '連絡は captain@example.com か 090-1234-5678 へお願いします。',
    );

    expect(review.canPost, isFalse);
    expect(review.severity, GuildPostingReviewSeverity.blocked);
    expect(review.issues.first.label, '連絡先');
  });

  test('warns about location and pressure language', () {
    final review = service.review('最寄り駅の近くで今すぐ必ず返信してください。');

    expect(review.canPost, isTrue);
    expect(review.severity, GuildPostingReviewSeverity.caution);
    expect(review.issues.map((issue) => issue.label), contains('場所情報'));
    expect(review.issues.map((issue) => issue.label), contains('表現'));
  });

  test('allows normal Quest consultation text', () {
    final review = service.review('富士山に登るQuestで、最初のMissionを小さくしたいです。');

    expect(review.canPost, isTrue);
    expect(review.severity, GuildPostingReviewSeverity.safe);
    expect(review.issues, isEmpty);
  });
}
