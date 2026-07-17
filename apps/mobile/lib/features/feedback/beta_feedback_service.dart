import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'beta_feedback_model.dart';
import 'beta_feedback_triage_service.dart';

final betaFeedbackServiceProvider = Provider<BetaFeedbackService>((ref) {
  return const BetaFeedbackService();
});

final betaFeedbackSinkProvider = Provider<BetaFeedbackSink>((ref) {
  return const ClipboardBetaFeedbackSink();
});

class BetaFeedbackService {
  const BetaFeedbackService();

  BetaFeedbackReport createReport({
    required BetaFeedbackDraft draft,
    required String testerId,
    required String buildVersion,
    DateTime? now,
  }) {
    if (!draft.isComplete) {
      throw ArgumentError('Feedback fields must not be empty.');
    }
    final createdAt = (now ?? DateTime.now()).toUtc();
    return BetaFeedbackReport(
      id: 'beta-${createdAt.microsecondsSinceEpoch}',
      createdAt: createdAt,
      testerId: testerId.trim().isEmpty ? 'anonymous-beta' : testerId.trim(),
      buildVersion: buildVersion.trim().isEmpty
          ? 'local-beta'
          : buildVersion.trim(),
      draft: BetaFeedbackDraft(
        surface: draft.surface,
        type: draft.type,
        severity: draft.severity,
        summary: draft.summary.trim(),
        steps: draft.steps.trim(),
        expected: draft.expected.trim(),
        actual: draft.actual.trim(),
      ),
    );
  }

  String format(BetaFeedbackReport report) {
    final draft = report.draft;
    final triage = const BetaFeedbackTriageService().classify(report);
    return '''Questra Beta Feedback
report_id: ${report.id}
created_at: ${report.createdAt.toIso8601String()}
tester_id: ${report.testerId}
build_version: ${report.buildVersion}
surface: ${draft.surface.storageKey}
feedback_type: ${draft.type.storageKey}
severity: ${draft.severity.code}
suggested_labels: ${triage.labels.join(', ')}
suggested_priority: ${triage.priority.code}
qst_candidate: ${triage.shouldCreateQst}
stops_beta_expansion: ${triage.stopsBetaExpansion}

概要
${draft.summary}

再現手順
${draft.steps}

期待した結果
${draft.expected}

実際の結果
${draft.actual}''';
  }
}

abstract interface class BetaFeedbackSink {
  Future<void> submit(BetaFeedbackReport report);
}

class ClipboardBetaFeedbackSink implements BetaFeedbackSink {
  const ClipboardBetaFeedbackSink();

  @override
  Future<void> submit(BetaFeedbackReport report) {
    final text = const BetaFeedbackService().format(report);
    return Clipboard.setData(ClipboardData(text: text));
  }
}
