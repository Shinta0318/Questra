import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/feedback/beta_feedback_model.dart';
import 'package:questra/features/feedback/beta_feedback_triage_service.dart';

void main() {
  const service = BetaFeedbackTriageService();

  test('maps feedback into every supported issue category', () {
    final cases =
        <({BetaFeedbackReport report, Set<BetaIssueCategory> expected})>[
          (
            report: _report(
              type: BetaFeedbackType.crash,
              surface: BetaFeedbackSurface.home,
            ),
            expected: {BetaIssueCategory.bug},
          ),
          (
            report: _report(
              type: BetaFeedbackType.visualPolish,
              surface: BetaFeedbackSurface.design,
            ),
            expected: {BetaIssueCategory.ux},
          ),
          (
            report: _report(
              type: BetaFeedbackType.dataLoss,
              surface: BetaFeedbackSurface.rls,
            ),
            expected: {BetaIssueCategory.data},
          ),
          (
            report: _report(
              type: BetaFeedbackType.confusingCopy,
              surface: BetaFeedbackSurface.arcChat,
            ),
            expected: {
              BetaIssueCategory.ux,
              BetaIssueCategory.ai,
              BetaIssueCategory.arc,
            },
          ),
          (
            report: _report(
              type: BetaFeedbackType.idea,
              surface: BetaFeedbackSurface.guild,
            ),
            expected: {BetaIssueCategory.ux, BetaIssueCategory.guild},
          ),
          (
            report: _report(
              type: BetaFeedbackType.slowResponse,
              surface: BetaFeedbackSurface.performance,
            ),
            expected: {BetaIssueCategory.performance},
          ),
        ];

    for (final item in cases) {
      expect(
        service.classify(item.report).categories,
        containsAll(item.expected),
      );
    }
  });

  test('crash and data boundary reports stop beta as P0 QST candidates', () {
    final crash = service.classify(
      _report(
        type: BetaFeedbackType.crash,
        surface: BetaFeedbackSurface.quest,
        severity: BetaFeedbackSeverity.s2,
      ),
    );
    final dataLoss = service.classify(
      _report(
        type: BetaFeedbackType.dataLoss,
        surface: BetaFeedbackSurface.media,
        severity: BetaFeedbackSeverity.s3,
      ),
    );

    for (final triage in [crash, dataLoss]) {
      expect(triage.priority, BetaQstPriority.p0);
      expect(triage.shouldCreateQst, isTrue);
      expect(triage.stopsBetaExpansion, isTrue);
    }
  });

  test('repeated S2 feedback becomes a P1 QST candidate', () {
    final report = _report(
      type: BetaFeedbackType.missingState,
      surface: BetaFeedbackSurface.mission,
      severity: BetaFeedbackSeverity.s2,
    );

    expect(service.classify(report).shouldCreateQst, isFalse);
    final repeated = service.classify(report, repetitionCount: 3);
    final candidate = service.buildQstCandidate(report, repetitionCount: 3);

    expect(repeated.priority, BetaQstPriority.p1);
    expect(repeated.shouldCreateQst, isTrue);
    expect(candidate, isNotNull);
    expect(candidate!.title, contains('[S2][Mission]'));
    expect(candidate.labels, contains('ux'));
    expect(candidate.evidence, contains('Report beta-test'));
  });

  test('single S3 idea stays in review without automatic QST creation', () {
    final report = _report(
      type: BetaFeedbackType.idea,
      surface: BetaFeedbackSurface.home,
      severity: BetaFeedbackSeverity.s3,
    );

    final triage = service.classify(report);

    expect(triage.priority, BetaQstPriority.p2);
    expect(triage.shouldCreateQst, isFalse);
    expect(triage.stopsBetaExpansion, isFalse);
    expect(service.buildQstCandidate(report), isNull);
  });
}

BetaFeedbackReport _report({
  required BetaFeedbackType type,
  required BetaFeedbackSurface surface,
  BetaFeedbackSeverity severity = BetaFeedbackSeverity.s2,
}) {
  return BetaFeedbackReport(
    id: 'beta-test',
    createdAt: DateTime.utc(2026, 7, 17),
    testerId: 'tester',
    buildVersion: 'beta-125',
    draft: BetaFeedbackDraft(
      surface: surface,
      type: type,
      severity: severity,
      summary: '報告された問題',
      steps: '1. 対象画面を開く\n2. 操作する',
      expected: '期待した状態になる',
      actual: '期待と異なる状態になった',
    ),
  );
}
