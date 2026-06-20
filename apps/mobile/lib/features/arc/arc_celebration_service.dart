import 'package:flutter/material.dart';

import '../../widgets/arc/arc_emotion.dart';
import '../../widgets/arc/arc_widget.dart';
import '../../widgets/questra_card.dart';
import 'arc_expression_engine.dart';

enum ArcCelebrationEvent {
  missionStarted,
  missionCompleted,
  trailRecorded,
  trailReflection,
  questProgress,
  bondMilestone,
  rankMilestone,
}

class ArcCelebrationMoment {
  const ArcCelebrationMoment({
    required this.event,
    required this.emotion,
    required this.title,
    required this.message,
    required this.reason,
  });

  final ArcCelebrationEvent event;
  final ArcEmotion emotion;
  final String title;
  final String message;
  final String reason;
}

class ArcCelebrationService {
  const ArcCelebrationService({
    this.expressionEngine = const ArcExpressionEngine(),
  });

  final ArcExpressionEngine expressionEngine;

  ArcCelebrationMoment build({
    required ArcCelebrationEvent event,
    String? subject,
  }) {
    final decision = expressionEngine.resolve(
      const ArcExpressionContext(moment: ArcExpressionMoment.celebration),
    );
    final copy = _copyFor(event, subject);

    return ArcCelebrationMoment(
      event: event,
      emotion: decision.emotion,
      title: copy.title,
      message: copy.message,
      reason: decision.reason,
    );
  }

  _ArcCelebrationCopy _copyFor(ArcCelebrationEvent event, String? subject) {
    final name = subject == null || subject.trim().isEmpty
        ? null
        : subject.trim();

    return switch (event) {
      ArcCelebrationEvent.missionStarted => _ArcCelebrationCopy(
        title: 'Mission点灯',
        message: name == null
            ? '新しい一歩が見えたね。小さく進めば、Trailは自然に育っていくよ。'
            : '「$name」から新しいMissionが灯ったよ。今日の一歩にしよう。',
      ),
      ArcCelebrationEvent.missionCompleted => _ArcCelebrationCopy(
        title: 'Mission達成',
        message: name == null
            ? '今日の一歩がTrailになったよ。この前進はちゃんと残っている。'
            : '「$name」を完了したね。今日の一歩がTrailになったよ。',
      ),
      ArcCelebrationEvent.trailRecorded => _ArcCelebrationCopy(
        title: 'Trail記録',
        message: name == null
            ? '進み方を残せたね。この足あとが次の判断を助けてくれるよ。'
            : '「$name」のTrailを残せたね。この足あとが次の判断を助けてくれるよ。',
      ),
      ArcCelebrationEvent.trailReflection => _ArcCelebrationCopy(
        title: 'Reflection保存',
        message: name == null
            ? '気づきを残せたね。次のMissionを選ぶ手がかりになるよ。'
            : '「$name」のReflectionを残せたね。次のMissionにつながる光だよ。',
      ),
      ArcCelebrationEvent.questProgress => _ArcCelebrationCopy(
        title: 'Quest進行中',
        message: name == null
            ? 'もう少しでこのQuestは大きな星になる。最後の一歩を一緒に見よう。'
            : '「$name」は大きく進んでいるよ。最後の一歩を一緒に見よう。',
      ),
      ArcCelebrationEvent.bondMilestone => _ArcCelebrationCopy(
        title: 'Bond成長',
        message: '一緒に重ねた行動が、Arcとのつながりを少し強くしたよ。',
      ),
      ArcCelebrationEvent.rankMilestone => _ArcCelebrationCopy(
        title: 'Navigator Rank',
        message: '旅路の深さが新しいRankにつながったよ。この航路は育っている。',
      ),
    };
  }
}

class ArcCelebrationCard extends StatelessWidget {
  const ArcCelebrationCard({required this.moment, super.key});

  final ArcCelebrationMoment moment;

  @override
  Widget build(BuildContext context) {
    return QuestraCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ArcWidget(emotion: moment.emotion, size: 76, showSpeechBubble: false),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  moment.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(moment.message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void showArcCelebrationSnackBar(
  BuildContext context,
  ArcCelebrationMoment moment,
) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ArcWidget(emotion: moment.emotion, size: 48, showSpeechBubble: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  moment.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(moment.message),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ArcCelebrationCopy {
  const _ArcCelebrationCopy({required this.title, required this.message});

  final String title;
  final String message;
}
