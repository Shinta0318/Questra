import 'package:uuid/uuid.dart';

import '../quest/arc_quest_guide_service.dart';
import '../quest/quest_guide_model.dart';
import 'mission_model.dart';

const _uuid = Uuid();

class MissionCandidateDraft {
  MissionCandidateDraft({
    String? id,
    required this.title,
    required this.description,
    required this.guideType,
    required this.difficulty,
    this.isToday = false,
  }) : id = id ?? _uuid.v4();

  factory MissionCandidateDraft.fromArcCandidate(
    ArcMissionCandidate candidate,
  ) {
    return MissionCandidateDraft(
      title: candidate.title,
      description: candidate.description,
      guideType: candidate.guideType,
      difficulty: candidate.difficulty,
    );
  }

  final String id;
  final String title;
  final String description;
  final GuideType guideType;
  final MissionDifficulty difficulty;
  final bool isToday;

  MissionCandidateDraft copyWith({
    String? title,
    String? description,
    GuideType? guideType,
    MissionDifficulty? difficulty,
    bool? isToday,
  }) {
    return MissionCandidateDraft(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      guideType: guideType ?? this.guideType,
      difficulty: difficulty ?? this.difficulty,
      isToday: isToday ?? this.isToday,
    );
  }
}

class MissionPlanDraft {
  const MissionPlanDraft({required this.candidates});

  factory MissionPlanDraft.fromArcGuide(ArcQuestGuide guide) {
    return MissionPlanDraft(
      candidates: guide.missionCandidates
          .take(10)
          .map(MissionCandidateDraft.fromArcCandidate)
          .toList(growable: false),
    );
  }

  final List<MissionCandidateDraft> candidates;

  MissionPlanDraft update(MissionCandidateDraft updated) {
    return MissionPlanDraft(
      candidates: [
        for (final candidate in candidates)
          if (candidate.id == updated.id) updated else candidate,
      ],
    );
  }

  MissionPlanDraft add() {
    if (candidates.length >= 10) return this;
    return MissionPlanDraft(
      candidates: [
        ...candidates,
        MissionCandidateDraft(
          title: '新しいMission',
          description: '今日できる小さな一歩に整えます。',
          guideType: GuideType.route,
          difficulty: MissionDifficulty.easy,
        ),
      ],
    );
  }

  MissionPlanDraft remove(String id) {
    if (candidates.length <= 1) return this;
    return MissionPlanDraft(
      candidates: candidates.where((candidate) => candidate.id != id).toList(),
    );
  }

  MissionPlanDraft move(int from, int to) {
    if (from == to || from < 0 || from >= candidates.length) return this;
    if (to < 0 || to >= candidates.length) return this;
    final reordered = [...candidates];
    final candidate = reordered.removeAt(from);
    reordered.insert(to, candidate);
    return MissionPlanDraft(candidates: reordered);
  }

  MissionPlanDraft markToday(String id) {
    return MissionPlanDraft(
      candidates: [
        for (final candidate in candidates)
          candidate.copyWith(isToday: candidate.id == id),
      ],
    );
  }

  List<MissionCandidateDraft> get validCandidates => candidates
      .where((candidate) => candidate.title.trim().isNotEmpty)
      .take(10)
      .toList(growable: false);
}
