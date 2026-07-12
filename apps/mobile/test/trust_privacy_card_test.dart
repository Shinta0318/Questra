import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/settings/widgets/trust_privacy_card.dart';
import 'package:questra/features/trust/trust_privacy_review_service.dart';

void main() {
  testWidgets('renders the trust review and future actions', (tester) async {
    final review = const TrustPrivacyReviewService().buildReview();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: TrustPrivacyCard(review: review)),
        ),
      ),
    );

    expect(find.text(review.heading), findsOneWidget);
    expect(find.text('Quest / Mission / Trail'), findsOneWidget);
    expect(find.text('今後追加する操作'), findsOneWidget);
    expect(find.text('データ削除リクエスト'), findsOneWidget);
  });
}
