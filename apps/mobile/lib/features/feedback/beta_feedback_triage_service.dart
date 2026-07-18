import 'beta_feedback_model.dart';

enum BetaIssueCategory { bug, ux, data, ai, guild, arc, performance }

extension BetaIssueCategoryLabel on BetaIssueCategory {
  String get storageKey => name;
}

enum BetaQstPriority { p0, p1, p2 }

extension BetaQstPriorityLabel on BetaQstPriority {
  String get code => name.toUpperCase();
}

class BetaFeedbackTriage {
  const BetaFeedbackTriage({
    required this.categories,
    required this.labels,
    required this.priority,
    required this.shouldCreateQst,
    required this.stopsBetaExpansion,
    required this.reason,
  });

  final Set<BetaIssueCategory> categories;
  final List<String> labels;
  final BetaQstPriority priority;
  final bool shouldCreateQst;
  final bool stopsBetaExpansion;
  final String reason;
}

class BetaQstCandidate {
  const BetaQstCandidate({
    required this.title,
    required this.priority,
    required this.labels,
    required this.problem,
    required this.evidence,
    required this.scope,
    required this.acceptance,
    required this.validation,
  });

  final String title;
  final BetaQstPriority priority;
  final List<String> labels;
  final String problem;
  final String evidence;
  final String scope;
  final String acceptance;
  final String validation;
}

class BetaFeedbackTriageService {
  const BetaFeedbackTriageService();

  BetaFeedbackTriage classify(
    BetaFeedbackReport report, {
    int repetitionCount = 1,
    bool strategicallyAligned = false,
  }) {
    final draft = report.draft;
    final categories = <BetaIssueCategory>{};

    switch (draft.type) {
      case BetaFeedbackType.crash:
      case BetaFeedbackType.brokenFlow:
        categories.add(BetaIssueCategory.bug);
      case BetaFeedbackType.dataLoss:
      case BetaFeedbackType.trustOrSafety:
        categories.add(BetaIssueCategory.data);
      case BetaFeedbackType.confusingCopy:
      case BetaFeedbackType.visualPolish:
      case BetaFeedbackType.missingState:
      case BetaFeedbackType.idea:
        categories.add(BetaIssueCategory.ux);
      case BetaFeedbackType.slowResponse:
        categories.add(BetaIssueCategory.performance);
    }

    switch (draft.surface) {
      case BetaFeedbackSurface.guild:
        categories.add(BetaIssueCategory.guild);
      case BetaFeedbackSurface.arcChat:
      case BetaFeedbackSurface.arcMemory:
        categories
          ..add(BetaIssueCategory.arc)
          ..add(BetaIssueCategory.ai);
      case BetaFeedbackSurface.performance:
        categories.add(BetaIssueCategory.performance);
      case BetaFeedbackSurface.rls:
        categories.add(BetaIssueCategory.data);
      case BetaFeedbackSurface.home:
      case BetaFeedbackSurface.quest:
      case BetaFeedbackSurface.mission:
      case BetaFeedbackSurface.trail:
      case BetaFeedbackSurface.profile:
      case BetaFeedbackSurface.media:
      case BetaFeedbackSurface.auth:
      case BetaFeedbackSurface.design:
      case BetaFeedbackSurface.other:
        break;
    }

    final isCrash = draft.type == BetaFeedbackType.crash;
    final isDataBoundary =
        draft.type == BetaFeedbackType.dataLoss ||
        draft.type == BetaFeedbackType.trustOrSafety ||
        draft.surface == BetaFeedbackSurface.rls;
    final stopsBeta =
        draft.severity == BetaFeedbackSeverity.s0 || isCrash || isDataBoundary;
    final priority = stopsBeta || draft.severity == BetaFeedbackSeverity.s1
        ? BetaQstPriority.p0
        : draft.severity == BetaFeedbackSeverity.s2
        ? BetaQstPriority.p1
        : BetaQstPriority.p2;
    final repeated = repetitionCount >= 3;
    final shouldCreateQst =
        draft.severity == BetaFeedbackSeverity.s0 ||
        draft.severity == BetaFeedbackSeverity.s1 ||
        isCrash ||
        isDataBoundary ||
        (repeated &&
            (draft.severity == BetaFeedbackSeverity.s2 ||
                strategicallyAligned));
    final sortedCategories = categories.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final labels = <String>[
      'beta',
      'severity:${draft.severity.code}',
      'surface:${draft.surface.storageKey}',
      'type:${draft.type.storageKey}',
      ...sortedCategories.map((category) => category.storageKey),
    ];

    return BetaFeedbackTriage(
      categories: categories,
      labels: labels,
      priority: priority,
      shouldCreateQst: shouldCreateQst,
      stopsBetaExpansion: stopsBeta,
      reason: _reason(
        report,
        repeated: repeated,
        strategicallyAligned: strategicallyAligned,
      ),
    );
  }

  BetaQstCandidate? buildQstCandidate(
    BetaFeedbackReport report, {
    int repetitionCount = 1,
    bool strategicallyAligned = false,
  }) {
    final triage = classify(
      report,
      repetitionCount: repetitionCount,
      strategicallyAligned: strategicallyAligned,
    );
    if (!triage.shouldCreateQst) return null;
    final draft = report.draft;
    return BetaQstCandidate(
      title:
          '[${draft.severity.code}][${draft.surface.label}] ${draft.summary}',
      priority: triage.priority,
      labels: triage.labels,
      problem: draft.actual,
      evidence:
          'Report ${report.id} / build ${report.buildVersion}\n${draft.steps}',
      scope: '${draft.surface.label}で報告された問題を再現し、中心フローを壊さずに解消する。',
      acceptance: draft.expected,
      validation: '再現手順を回帰テストへ追加し、関連するFlutterテストと静的解析を通す。',
    );
  }

  String _reason(
    BetaFeedbackReport report, {
    required bool repeated,
    required bool strategicallyAligned,
  }) {
    final draft = report.draft;
    if (draft.severity == BetaFeedbackSeverity.s0 ||
        draft.type == BetaFeedbackType.crash) {
      return 'Beta継続を止め、P0 QSTとして扱います。';
    }
    if (draft.type == BetaFeedbackType.dataLoss ||
        draft.type == BetaFeedbackType.trustOrSafety ||
        draft.surface == BetaFeedbackSurface.rls) {
      return 'データ・信頼境界の報告は1件でもP0 QSTとして扱います。';
    }
    if (draft.severity == BetaFeedbackSeverity.s1) {
      return '主要なBeta問題として24時間以内にP0 QSTへ変換します。';
    }
    if (repeated) {
      return '同種の報告が3件に達したためQST候補へ昇格します。';
    }
    if (strategicallyAligned) {
      return 'プロダクト方針に沿う提案として週次レビュー対象にします。';
    }
    return draft.severity == BetaFeedbackSeverity.s2
        ? '次回Beta polishでまとめて確認します。'
        : '同種報告の回数を追跡し、週次レビューで確認します。';
  }
}
