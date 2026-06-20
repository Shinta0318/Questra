import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/arc/arc_emotion.dart';
import '../mission/mission_model.dart';
import '../trail/trail_model.dart';

final arcReflectionCoachServiceProvider = Provider<ArcReflectionCoachService>(
  (ref) => const ArcReflectionCoachService(),
);

class ArcReflectionCoach {
  const ArcReflectionCoach({
    required this.message,
    required this.learningPrompt,
    required this.nextMissionPrompt,
    required this.feedbackHint,
    required this.emotion,
  });

  final String message;
  final String learningPrompt;
  final String nextMissionPrompt;
  final String feedbackHint;
  final ArcEmotion emotion;
}

class ArcReflectionCoachService {
  const ArcReflectionCoachService();

  ArcReflectionCoach build({required Trail trail, Mission? mission}) {
    if (mission != null) {
      return ArcReflectionCoach(
        message:
            '「${mission.title}」のTrailを一緒に振り返ろう。できたことだけでなく、次に小さくする場所も星図に残せます。',
        learningPrompt: 'このMissionで分かったことは？',
        nextMissionPrompt: '次に10分で進めるMissionは？',
        feedbackHint: 'Arcの視点: Missionの結果を「学び」と「次の一歩」に分けると、Questの航路が続きやすくなります。',
        emotion: mission.status == MissionStatus.completed
            ? ArcEmotion.celebrate
            : ArcEmotion.support,
      );
    }

    if (trail.trailType == TrailType.manualNote) {
      return const ArcReflectionCoach(
        message: 'このTrailには、まだ名前のない気づきがありそうです。小さな手がかりを一緒に拾いましょう。',
        learningPrompt: 'この記録から見えた気づきは？',
        nextMissionPrompt: '次に試したい小さな行動は？',
        feedbackHint: 'Arcの視点: まだQuestに結びつかない記録も、あとで大切な星になります。',
        emotion: ArcEmotion.normal,
      );
    }

    return ArcReflectionCoach(
      message: '「${trail.title}」の航路を振り返りましょう。進んだ距離より、次に迷わない印を残すことが大切です。',
      learningPrompt: 'このTrailで学んだことは？',
      nextMissionPrompt: '次のMissionにするとしたら？',
      feedbackHint: 'Arcの視点: Trailを一行でも振り返ると、QuestからMissionへの流れがまた動き出します。',
      emotion: ArcEmotion.support,
    );
  }
}
