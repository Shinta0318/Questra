import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/trust/trust_privacy_review_service.dart';

void main() {
  const service = TrustPrivacyReviewService();

  test('builds Master Spec aligned trust and privacy review items', () {
    final review = service.buildReview();

    expect(review.heading, 'データとプライバシー');
    expect(review.summary, contains('保存される内容'));
    expect(
      review.items.map((item) => item.area),
      containsAll(TrustPrivacyArea.values),
    );
    expect(
      review.items
          .firstWhere((item) => item.area == TrustPrivacyArea.arcMemory)
          .userControl,
      contains('自動共有しません'),
    );
    final arcGeneration = review.items.firstWhere(
      (item) => item.area == TrustPrivacyArea.aiTransparency,
    );
    expect(arcGeneration.summary, contains('Gemini API'));
    expect(arcGeneration.summary, contains('OpenAI互換経路'));
    expect(arcGeneration.userControl, contains('request保存は無効'));
    expect(arcGeneration.summary, contains('Arc Memory'));
    expect(arcGeneration.userControl, contains('誤ることがある'));
    expect(
      review.items
          .firstWhere((item) => item.area == TrustPrivacyArea.questSupport)
          .statusLabel,
      'Betaでは未接続',
    );
    expect(review.futureActions, contains('データエクスポート'));
    expect(review.betaNotices, contains(contains('自動送信しません')));
    expect(review.betaNotices, contains(contains('まだ利用できません')));
    expect(review.legalStatus, contains('法務確認'));
  });
}
