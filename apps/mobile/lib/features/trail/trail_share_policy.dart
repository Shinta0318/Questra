import 'trail_model.dart';

enum TrailShareField { title, summary, content }

class TrailShareDraft {
  const TrailShareDraft({
    required this.trail,
    required this.fields,
    required this.expiresAt,
  });

  final Trail trail;
  final Set<TrailShareField> fields;
  final DateTime expiresAt;
}

class TrailShareReview {
  const TrailShareReview({required this.isSafe, this.reason});

  final bool isSafe;
  final String? reason;
}

class TrailSharePolicy {
  const TrailSharePolicy();

  static const maxLifetime = Duration(days: 30);

  TrailShareReview review(TrailShareDraft draft, {DateTime? now}) {
    final current = (now ?? DateTime.now()).toUtc();
    if (draft.fields.isEmpty) {
      return const TrailShareReview(isSafe: false, reason: '共有する項目を1つ選んでください。');
    }
    if (!draft.expiresAt.toUtc().isAfter(current) ||
        draft.expiresAt.toUtc().difference(current) > maxLifetime) {
      return const TrailShareReview(isSafe: false, reason: '共有期限は30日以内で設定してください。');
    }
    final selected = <String>[
      if (draft.fields.contains(TrailShareField.title)) draft.trail.title,
      if (draft.fields.contains(TrailShareField.summary)) draft.trail.summary,
      if (draft.fields.contains(TrailShareField.content)) draft.trail.content,
    ].join('\n');
    if (_hasPersonalContact(selected)) {
      return const TrailShareReview(
        isSafe: false,
        reason: 'メールアドレスまたは電話番号らしき内容があります。削除してから共有してください。',
      );
    }
    return const TrailShareReview(isSafe: true);
  }

  bool _hasPersonalContact(String value) {
    return RegExp(r'\b[\w.+-]+@[\w-]+\.[\w.-]+\b').hasMatch(value) ||
        RegExp(r'(?<!\d)(?:\+?81[-\s]?)?0\d{1,4}[-\s]?\d{1,4}[-\s]?\d{3,4}(?!\d)')
            .hasMatch(value);
  }
}
