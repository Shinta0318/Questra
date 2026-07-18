enum BetaFeedbackSurface {
  home,
  quest,
  mission,
  trail,
  guild,
  arcChat,
  arcMemory,
  profile,
  media,
  auth,
  rls,
  performance,
  design,
  other,
}

extension BetaFeedbackSurfaceLabel on BetaFeedbackSurface {
  String get label => switch (this) {
    BetaFeedbackSurface.home => 'Home',
    BetaFeedbackSurface.quest => 'Quest',
    BetaFeedbackSurface.mission => 'Mission',
    BetaFeedbackSurface.trail => 'Trail',
    BetaFeedbackSurface.guild => 'Guild',
    BetaFeedbackSurface.arcChat => 'Arc Chat',
    BetaFeedbackSurface.arcMemory => 'Arc Memory',
    BetaFeedbackSurface.profile => 'プロフィール',
    BetaFeedbackSurface.media => '画像・メディア',
    BetaFeedbackSurface.auth => 'ログイン・アカウント',
    BetaFeedbackSurface.rls => 'データの所有者・公開範囲',
    BetaFeedbackSurface.performance => '動作速度',
    BetaFeedbackSurface.design => 'デザイン',
    BetaFeedbackSurface.other => 'その他',
  };

  String get storageKey => switch (this) {
    BetaFeedbackSurface.arcChat => 'arc_chat',
    BetaFeedbackSurface.arcMemory => 'arc_memory',
    _ => name,
  };
}

enum BetaFeedbackType {
  crash,
  dataLoss,
  brokenFlow,
  confusingCopy,
  visualPolish,
  slowResponse,
  missingState,
  trustOrSafety,
  idea,
}

extension BetaFeedbackTypeLabel on BetaFeedbackType {
  String get label => switch (this) {
    BetaFeedbackType.crash => 'クラッシュ・操作不能',
    BetaFeedbackType.dataLoss => 'データが消えた・違って見える',
    BetaFeedbackType.brokenFlow => '操作の流れが進まない',
    BetaFeedbackType.confusingCopy => '言葉が分かりにくい',
    BetaFeedbackType.visualPolish => '表示・デザイン',
    BetaFeedbackType.slowResponse => '動作が遅い',
    BetaFeedbackType.missingState => '空・読込・エラー表示',
    BetaFeedbackType.trustOrSafety => '安全・プライバシー',
    BetaFeedbackType.idea => '改善アイデア',
  };

  String get storageKey => switch (this) {
    BetaFeedbackType.dataLoss => 'data_loss',
    BetaFeedbackType.brokenFlow => 'broken_flow',
    BetaFeedbackType.confusingCopy => 'confusing_copy',
    BetaFeedbackType.visualPolish => 'visual_polish',
    BetaFeedbackType.slowResponse => 'slow_response',
    BetaFeedbackType.missingState => 'missing_state',
    BetaFeedbackType.trustOrSafety => 'trust_or_safety',
    _ => name,
  };
}

enum BetaFeedbackSeverity { s0, s1, s2, s3 }

extension BetaFeedbackSeverityLabel on BetaFeedbackSeverity {
  String get code => name.toUpperCase();

  String get label => switch (this) {
    BetaFeedbackSeverity.s0 => 'S0 - 継続できない重大問題',
    BetaFeedbackSeverity.s1 => 'S1 - 主要な操作が使えない',
    BetaFeedbackSeverity.s2 => 'S2 - 使いづらい・分かりにくい',
    BetaFeedbackSeverity.s3 => 'S3 - 改善アイデア',
  };
}

class BetaFeedbackDraft {
  const BetaFeedbackDraft({
    required this.surface,
    required this.type,
    required this.severity,
    required this.summary,
    required this.steps,
    required this.expected,
    required this.actual,
  });

  final BetaFeedbackSurface surface;
  final BetaFeedbackType type;
  final BetaFeedbackSeverity severity;
  final String summary;
  final String steps;
  final String expected;
  final String actual;

  bool get isComplete =>
      summary.trim().isNotEmpty &&
      steps.trim().isNotEmpty &&
      expected.trim().isNotEmpty &&
      actual.trim().isNotEmpty;
}

class BetaFeedbackReport {
  const BetaFeedbackReport({
    required this.id,
    required this.createdAt,
    required this.testerId,
    required this.buildVersion,
    required this.draft,
  });

  final String id;
  final DateTime createdAt;
  final String testerId;
  final String buildVersion;
  final BetaFeedbackDraft draft;
}
