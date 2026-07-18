import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class ArcQuestCandidate {
  ArcQuestCandidate({String? id, required this.title}) : id = id ?? _uuid.v4();

  final String id;
  final String title;

  ArcQuestCandidate copyWith({String? title}) =>
      ArcQuestCandidate(id: id, title: title ?? this.title);
}

class ArcQuestDraft {
  const ArcQuestDraft({required this.input, required this.candidates});

  final String input;
  final List<ArcQuestCandidate> candidates;

  ArcQuestDraft update(String id, String title) => ArcQuestDraft(
    input: input,
    candidates: [
      for (final candidate in candidates)
        if (candidate.id == id) candidate.copyWith(title: title) else candidate,
    ],
  );

  ArcQuestDraft add([String title = '新しいQuest']) {
    if (candidates.length >= 7) return this;
    return ArcQuestDraft(
      input: input,
      candidates: [
        ...candidates,
        ArcQuestCandidate(title: title),
      ],
    );
  }

  ArcQuestDraft remove(String id) {
    if (candidates.length <= 1) return this;
    return ArcQuestDraft(
      input: input,
      candidates: candidates.where((candidate) => candidate.id != id).toList(),
    );
  }

  ArcQuestDraft move(int from, int to) {
    if (from == to || from < 0 || from >= candidates.length) return this;
    if (to < 0 || to >= candidates.length) return this;
    final reordered = [...candidates];
    final candidate = reordered.removeAt(from);
    reordered.insert(to, candidate);
    return ArcQuestDraft(input: input, candidates: reordered);
  }

  List<ArcQuestCandidate> get validCandidates => candidates
      .where((candidate) => candidate.title.trim().isNotEmpty)
      .toList(growable: false);
}

abstract interface class ArcQuestCreationService {
  Future<ArcQuestDraft> generate({required String input, int variation = 0});
}

class LocalArcQuestCreationService implements ArcQuestCreationService {
  const LocalArcQuestCreationService();

  @override
  Future<ArcQuestDraft> generate({
    required String input,
    int variation = 0,
  }) async {
    final normalized = input.trim();
    if (normalized.isEmpty) {
      throw const FormatException('叶えたいことを入力してください。');
    }
    final seed = _shorten(normalized);
    final patterns = variation.isEven
        ? [
            '$seedを実現する',
            '$seedの最初の一歩を始める',
            '$seedを続けられる習慣をつくる',
            '$seedの成果を形にする',
            '$seedを誰かと分かち合う',
          ]
        : [
            '$seedへの航路を描く',
            '$seedに必要な力を身につける',
            '$seedを30日間続ける',
            '$seedの小さな成功を積み重ねる',
            '$seedを自分らしい形で達成する',
          ];
    return ArcQuestDraft(
      input: normalized,
      candidates: patterns
          .map((title) => ArcQuestCandidate(title: title))
          .toList(growable: false),
    );
  }

  String _shorten(String input) {
    final firstLine = input.split(RegExp(r'[\n。！？!?]')).first.trim();
    if (firstLine.length <= 28) return firstLine;
    return '${firstLine.substring(0, 28)}…';
  }
}
