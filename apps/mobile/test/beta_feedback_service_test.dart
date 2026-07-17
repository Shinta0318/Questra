import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/feedback/beta_feedback_model.dart';
import 'package:questra/features/feedback/beta_feedback_service.dart';

void main() {
  const service = BetaFeedbackService();

  test('creates a trimmed report with operations-compatible fields', () {
    const draft = BetaFeedbackDraft(
      surface: BetaFeedbackSurface.quest,
      type: BetaFeedbackType.brokenFlow,
      severity: BetaFeedbackSeverity.s1,
      summary: '  Quest詳細を開けない  ',
      steps: '  1. Questを開く\n2. カードを選ぶ  ',
      expected: '  Quest詳細が表示される  ',
      actual: '  画面が切り替わらない  ',
    );

    final report = service.createReport(
      draft: draft,
      testerId: ' tester-01 ',
      buildVersion: ' beta-124 ',
      now: DateTime.utc(2026, 7, 17, 3, 8),
    );
    final formatted = service.format(report);

    expect(report.testerId, 'tester-01');
    expect(report.buildVersion, 'beta-124');
    expect(report.draft.summary, 'Quest詳細を開けない');
    expect(formatted, contains('surface: quest'));
    expect(formatted, contains('feedback_type: broken_flow'));
    expect(formatted, contains('severity: S1'));
    expect(formatted, contains('再現手順'));
    expect(formatted, contains('期待した結果'));
    expect(formatted, contains('実際の結果'));
  });

  test('rejects a report with missing required detail', () {
    const draft = BetaFeedbackDraft(
      surface: BetaFeedbackSurface.home,
      type: BetaFeedbackType.idea,
      severity: BetaFeedbackSeverity.s3,
      summary: '',
      steps: 'Homeを開く',
      expected: '提案が見える',
      actual: '何も見えない',
    );

    expect(
      () => service.createReport(
        draft: draft,
        testerId: 'tester',
        buildVersion: 'beta',
      ),
      throwsArgumentError,
    );
  });
}
