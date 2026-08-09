import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/trust/data_request_copy_service.dart';

void main() {
  const service = DataRequestCopyService();

  test('builds data request copy with export and deletion operations', () {
    final review = service.buildReview();

    expect(review.heading, 'データリクエスト');
    expect(review.summary, contains('本人のもの'));
    expect(
      review.requests.map((request) => request.type),
      containsAll(DataRequestType.values),
    );
    expect(
      review.requests
          .firstWhere((request) => request.type == DataRequestType.export)
          .scope,
      containsAll(['Quest', 'Mission', 'Trail', 'Arc Memory', 'Profile']),
    );
    expect(
      review.requests
          .firstWhere((request) => request.type == DataRequestType.withdrawal)
          .statusLabel,
      '設定する',
    );
    expect(review.safetyNotes, contains('削除・エクスポートは無料で利用できる基本機能として扱う'));
  });
}
