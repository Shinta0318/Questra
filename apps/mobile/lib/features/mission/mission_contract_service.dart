class MissionContractService {
  const MissionContractService();

  String? validateTitle({
    required String questTitle,
    required String missionTitle,
    Iterable<String> existingTitles = const [],
  }) {
    final title = missionTitle.trim();
    if (title.isEmpty) return 'Mission名を入力してください。';
    if (isEquivalent(questTitle, title)) {
      return 'Questと同じ名前ではなく、次に行う具体的な一歩を書いてください。';
    }
    final normalized = normalize(title);
    if (existingTitles.any((existing) => normalize(existing) == normalized)) {
      return '同じQuestに同名のMissionがあります。別の具体的な一歩にしてください。';
    }
    return null;
  }

  String? distinctGeneratedTitle({
    required String questTitle,
    required String missionTitle,
    required Set<String> usedTitles,
  }) {
    var title = missionTitle.trim();
    if (title.isEmpty) return null;
    if (isEquivalent(questTitle, title)) {
      title = '達成条件を一文で決める';
    }
    final normalized = normalize(title);
    if (usedTitles.contains(normalized)) return null;
    usedTitles.add(normalized);
    return title;
  }

  bool isEquivalent(String left, String right) =>
      normalize(left) == normalize(right);

  String normalize(String value) => value.trim().toLowerCase().replaceAll(
    RegExp(r'[\s　\p{P}\p{S}]', unicode: true),
    '',
  );
}
