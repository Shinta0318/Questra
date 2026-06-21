enum GuildPostingReviewSeverity { safe, caution, blocked }

class GuildPostingReviewIssue {
  const GuildPostingReviewIssue({
    required this.label,
    required this.message,
    required this.severity,
  });

  final String label;
  final String message;
  final GuildPostingReviewSeverity severity;
}

class GuildPostingReview {
  const GuildPostingReview({required this.issues});

  final List<GuildPostingReviewIssue> issues;

  bool get canPost => issues.every(
    (issue) => issue.severity != GuildPostingReviewSeverity.blocked,
  );

  GuildPostingReviewSeverity get severity {
    if (issues.any(
      (issue) => issue.severity == GuildPostingReviewSeverity.blocked,
    )) {
      return GuildPostingReviewSeverity.blocked;
    }
    if (issues.any(
      (issue) => issue.severity == GuildPostingReviewSeverity.caution,
    )) {
      return GuildPostingReviewSeverity.caution;
    }
    return GuildPostingReviewSeverity.safe;
  }
}

class GuildSafePostingReviewService {
  const GuildSafePostingReviewService();

  GuildPostingReview review(String text) {
    final issues = <GuildPostingReviewIssue>[];
    final normalized = text.trim();

    if (_emailPattern.hasMatch(normalized) ||
        _phonePattern.hasMatch(normalized)) {
      issues.add(
        const GuildPostingReviewIssue(
          label: '連絡先',
          message: 'メールアドレスや電話番号はGuildに出さず、必要なら安全な連絡手段へ分けましょう。',
          severity: GuildPostingReviewSeverity.blocked,
        ),
      );
    }
    if (_addressPattern.hasMatch(normalized)) {
      issues.add(
        const GuildPostingReviewIssue(
          label: '場所情報',
          message: '自宅や学校、勤務先が分かる表現は少しぼかして投稿しましょう。',
          severity: GuildPostingReviewSeverity.caution,
        ),
      );
    }
    if (_pressureWords.any(normalized.contains)) {
      issues.add(
        const GuildPostingReviewIssue(
          label: '表現',
          message: '相手を急かす言葉は、相談しやすい表現へやわらげると安全です。',
          severity: GuildPostingReviewSeverity.caution,
        ),
      );
    }

    return GuildPostingReview(issues: issues);
  }

  static final _emailPattern = RegExp(
    r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
    caseSensitive: false,
  );
  static final _phonePattern = RegExp(r'(\+?\d[\d\s-]{8,}\d)');
  static final _addressPattern = RegExp(r'(住所|自宅|学校|勤務先|会社名|最寄り駅)');
  static const _pressureWords = ['絶対', '今すぐ', '必ず返信', '晒す', '許さない'];
}
