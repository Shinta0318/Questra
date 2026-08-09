enum ArcQuickActionIntent {
  discussWish,
  createQuest,
  chooseNextTask,
  reviewRoute,
  research,
  custom,
}

class ArcQuickAction {
  const ArcQuickAction({
    required this.intent,
    required this.label,
    required this.prompt,
  });

  final ArcQuickActionIntent intent;
  final String label;
  final String prompt;

  factory ArcQuickAction.fromLabel(String label) => switch (label) {
    'やりたいことを相談' => const ArcQuickAction(
      intent: ArcQuickActionIntent.discussWish,
      label: 'やりたいことを相談',
      prompt: 'まだ言葉になっていない、やりたいことを一緒に整理したい。',
    ),
    'Questを作る' => const ArcQuickAction(
      intent: ArcQuickActionIntent.createQuest,
      label: 'Questを作る',
      prompt: '叶えたいことをQuestにする相談を始めたい。',
    ),
    '今日の一歩を決める' || '小さな一歩' => ArcQuickAction(
      intent: ArcQuickActionIntent.chooseNextTask,
      label: label,
      prompt: '今の航路から、今日できる次のTaskを一緒に選びたい。',
    ),
    '計画を見直す' => const ArcQuickAction(
      intent: ArcQuickActionIntent.reviewRoute,
      label: '計画を見直す',
      prompt: '今の進み方に合わせて、Questの航路を見直したい。',
    ),
    '情報を調べる' => const ArcQuickAction(
      intent: ArcQuickActionIntent.research,
      label: '情報を調べる',
      prompt: '進行中のQuestに必要な最新情報を調べたい。',
    ),
    _ => ArcQuickAction(
      intent: ArcQuickActionIntent.custom,
      label: label,
      prompt: '$labelについてArcと相談したい。',
    ),
  };
}
