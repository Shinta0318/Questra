abstract final class QuestTitleService {
  static String normalize(String candidate, {String fallback = ''}) {
    final primary = _firstTitleLine(candidate);
    final fallbackTitle = _firstTitleLine(fallback);
    final source = primary.isNotEmpty ? primary : fallbackTitle;
    if (source.isEmpty) return '';

    return source
        .replaceFirst(RegExp(r'^(?:Quest|クエスト)(?:の名前|名)?\s*[:：]\s*'), '')
        .replaceFirst(RegExp(r'に行きたい$'), 'へ行く')
        .replaceFirst(RegExp(r'を始めたい$'), 'を始める')
        .replaceFirst(RegExp(r'できるようになりたい$'), 'できるようになる')
        .replaceFirst(RegExp(r'になりたい$'), 'になる')
        .replaceFirst(RegExp(r'したい$'), 'する')
        .trim();
  }

  static String _firstTitleLine(String value) {
    final normalized = value.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) return '';

    for (final rawLine in normalized.split('\n')) {
      final line = rawLine.replaceFirst(RegExp(r'^\s*[-*・•]\s*'), '').trim();
      if (line.isEmpty || line.startsWith('航路条件')) continue;
      final withoutInlineAnswer = line
          .split(RegExp(r'\s+[-–—]\s*(?=いつ|誰|予算|使える|旅で|どんな)'))
          .first
          .trim();
      if (withoutInlineAnswer.isNotEmpty) return withoutInlineAnswer;
    }
    return '';
  }
}
