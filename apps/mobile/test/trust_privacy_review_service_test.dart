import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/trust/trust_privacy_review_service.dart';

void main() {
  const service = TrustPrivacyReviewService();

  test('builds Master Spec aligned trust and privacy review items', () {
    final review = service.buildReview();

    expect(review.heading, 'Trust & Privacy');
    expect(review.summary, contains('本人の意思と同意'));
    expect(
      review.items.map((item) => item.area),
      containsAll(TrustPrivacyArea.values),
    );
    expect(
      review.items
          .firstWhere((item) => item.area == TrustPrivacyArea.arcMemory)
          .summary,
      contains('勝手に共有しません'),
    );
    expect(
      review.items
          .firstWhere((item) => item.area == TrustPrivacyArea.questSupport)
          .statusLabel,
      'Betaでは未接続',
    );
    expect(review.futureActions, contains('データエクスポート'));
  });
}
