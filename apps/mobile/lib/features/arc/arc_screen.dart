import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../widgets/arc/arc_emotion.dart';
import '../../widgets/arc/arc_empty_state.dart';
import '../../widgets/arc/arc_widget.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/layout/questra_screen_surface.dart';
import '../arc_memory/arc_memory_model.dart';
import '../arc_memory/arc_memory_providers.dart';
import '../auth/auth_controller.dart';
import '../mission/mission_controller.dart';
import '../mission/mission_model.dart';
import '../quest/quest_controller.dart';
import '../quest/arc_quest_creation_service.dart';
import '../quest/quest_model.dart';
import '../trail/trail_controller.dart';
import '../trail/trail_model.dart';
import 'arc_bond_growth_service.dart';
import 'arc_chat_service.dart';
import 'arc_emotion_timeline_controller.dart';
import 'arc_emotion_timeline_model.dart';
import 'arc_guidance_providers.dart';
import 'arc_action_trigger_service.dart';
import 'stardust_service.dart';

class ArcScreen extends ConsumerStatefulWidget {
  const ArcScreen({super.key});

  @override
  ConsumerState<ArcScreen> createState() => _ArcScreenState();
}

class _ArcScreenState extends ConsumerState<ArcScreen> {
  final _controller = TextEditingController();
  final List<ArcChatMessage> _messages = [
    ArcChatMessage(
      text: 'おかえり、キャプテン。\nどんなことを話したい？',
      fromArc: true,
      createdAt: DateTime.now(),
    ),
  ];
  bool _isThinking = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quests = ref.watch(questControllerProvider);
    final missions = ref.watch(missionControllerProvider);
    final trails = ref.watch(trailControllerProvider);
    final memories = ref.watch(visibleArcMemoriesProvider);
    final emotionEvents = ref.watch(arcEmotionTimelineControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      body: QuestraScreenSurface(
        child: Column(
          children: [
            const _ArcHeader(),
            Expanded(
              child: QuestraResponsiveListView(
                showScrollbar: true,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                children: [
                  _ArcCommandCenterCard(
                    activeQuestCount: quests
                        .where((quest) => quest.status == QuestStatus.active)
                        .length,
                    missionCount: missions.length,
                    trailCount: trails.length,
                    onOpenQuest: () => context.go(AppRoutes.quest),
                    onCreateQuest: _openQuestCreation,
                    onOpenTrail: () => context.go(AppRoutes.trail),
                    onHorizon: () => _send(
                      '次の挑戦の候補を一緒に探したい。',
                      quests: quests,
                      missions: missions,
                      trails: trails,
                      memories: memories.asData?.value ?? const [],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ..._messages.map(
                    (message) => _ArcMessageBubble(
                      text: message.text,
                      fromArc: message.fromArc,
                      emotion: message.fromArc
                          ? ArcEmotion.support
                          : ArcEmotion.normal,
                    ),
                  ),
                  if (_isThinking) const _ArcThinkingBubble(),
                  const _ShootingStarDivider(),
                  _ArcActionCard(
                    onQuickAction: (text) => _send(
                      text,
                      quests: quests,
                      missions: missions,
                      trails: trails,
                      memories: memories.asData?.value ?? const [],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _ArcEmotionTimelineCard(events: emotionEvents),
                  if ((memories.asData?.value ?? const []).isEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    ArcEmptyState(
                      title: 'Arc Memoryはまだ静かな星図です',
                      message:
                          'Quest、Mission、Trailを進めると、Arcが大切な手がかりを少しずつ覚えていきます。',
                      actionLabel: 'Questを進める',
                      icon: Icons.travel_explore_outlined,
                      onAction: () => context.go(AppRoutes.quest),
                    ),
                  ],
                ],
              ),
            ),
            _ArcInputBar(
              controller: _controller,
              onSend: () {
                _send(
                  _controller.text,
                  quests: quests,
                  missions: missions,
                  trails: trails,
                  memories: memories.asData?.value ?? const [],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openQuestCreation() async {
    final result = await showModalBottomSheet<_ArcQuestConfirmation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ArcQuestCreationSheet(),
    );
    if (result == null || !mounted) return;

    for (final candidate in result.candidates) {
      ref
          .read(questControllerProvider.notifier)
          .add(
            Quest(
              title: candidate.title.trim(),
              description: result.input,
              difficulty: QuestDifficulty.normal,
              status: QuestStatus.active,
              visibility: QuestVisibility.private,
              category: 'Arcと計画',
            ),
          );
    }
    setState(() {
      _messages.add(
        ArcChatMessage(
          text: '${result.candidates.length}つのQuestを星図に灯したよ。次はMissionに分けていこう。',
          fromArc: true,
          createdAt: DateTime.now(),
        ),
      );
    });
  }

  Future<void> _send(
    String rawText, {
    required List<Quest> quests,
    required List<Mission> missions,
    required List<Trail> trails,
    required List<ArcMemory> memories,
  }) async {
    final text = rawText.trim();
    if (text.isEmpty || _isThinking) {
      return;
    }

    _controller.clear();
    final userMessage = ArcChatMessage(
      text: text,
      fromArc: false,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isThinking = true;
    });
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .arcChatSent(
            userId: ref.read(authControllerProvider).profile?.id,
            hasQuest: quests.any((quest) => quest.status == QuestStatus.active),
            hasTrail: trails.isNotEmpty,
          ),
    );

    final context = ArcChatContext(
      activeQuests: quests
          .where((quest) => quest.status == QuestStatus.active)
          .toList(growable: false),
      recentMissions: missions.take(5).toList(growable: false),
      recentTrails: trails.take(5).toList(growable: false),
      memories: ref
          .read(arcMemoryRetrievalServiceProvider)
          .retrieve(
            memories: memories,
            query: text,
            questIds: quests
                .where((quest) => quest.status == QuestStatus.active)
                .map((quest) => quest.id)
                .toSet(),
          ),
    );

    try {
      final response = await ref
          .read(arcChatServiceProvider)
          .send(userMessage: text, history: _messages, context: context);
      final arcMessage = ArcChatMessage(
        text: response.message,
        fromArc: true,
        createdAt: DateTime.now(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(arcMessage);
        _isThinking = false;
      });
      _recordChatAction(ArcActionTrigger.arcChatResponded);
      await _rememberChat(userMessage, arcMessage, context);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(
          ArcChatMessage(
            text: '星雲が少しざわついているみたい。今は小さな一歩だけ一緒に選ぼう。',
            fromArc: true,
            createdAt: DateTime.now(),
          ),
        );
        _isThinking = false;
      });
      _recordChatAction(ArcActionTrigger.saveFailure);
    }
  }

  void _recordChatAction(ArcActionTrigger trigger) {
    final decision = ref
        .read(arcActionTriggerServiceProvider)
        .resolve(trigger: trigger, surface: 'Arc Chat');
    ref
        .read(arcEmotionTimelineControllerProvider.notifier)
        .record(
          emotion: decision.emotion,
          sourceType: decision.sourceType,
          reason: decision.message,
        );
  }

  Future<void> _rememberChat(
    ArcChatMessage userMessage,
    ArcChatMessage arcMessage,
    ArcChatContext context,
  ) async {
    final profile = ref.read(authControllerProvider).profile;
    if (profile == null) {
      return;
    }
    final quest = context.activeQuests.isEmpty
        ? null
        : context.activeQuests.first;
    final trail = context.recentTrails.isEmpty
        ? null
        : context.recentTrails.first;
    try {
      await ref
          .read(memoryExtractionServiceProvider)
          .extractAndSave(
            MemoryExtractionEvent(
              userId: profile.id,
              questId: quest?.id,
              trailId: trail?.id,
              sourceType: ArcMemorySourceType.arcChat,
              title: 'Arc conversation',
              text: 'User: ${userMessage.text}\nArc: ${arcMessage.text}',
              metadata: {
                'source': 'arc_chat',
                'message_count': _messages.length,
              },
            ),
          );
      final growth = ref
          .read(arcBondGrowthServiceProvider)
          .forArcConversation();
      final award = ref.read(stardustServiceProvider).forArcConversation();
      await ref
          .read(authControllerProvider.notifier)
          .addBondScore(delta: growth.delta, reason: growth.reason);
      await ref
          .read(authControllerProvider.notifier)
          .addStardust(amount: award.amount, reason: award.reason);
      ref.invalidate(visibleArcMemoriesProvider);
    } catch (_) {
      // Chat memory is helpful context, but the visible chat should not break.
    }
  }
}

class _ArcHeader extends StatelessWidget {
  const _ArcHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Arc',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: AppColors.white),
                ),
                Text(
                  '星の航海士',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.parchment,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.white.withValues(alpha: 0.08),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.42)),
              boxShadow: AppShadows.goldGlow,
            ),
            child: const ArcWidget(
              emotion: ArcEmotion.normal,
              size: 42,
              showSpeechBubble: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcMessageBubble extends StatelessWidget {
  const _ArcMessageBubble({
    required this.text,
    required this.fromArc,
    this.emotion = ArcEmotion.normal,
  });

  final String text;
  final bool fromArc;
  final ArcEmotion emotion;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: fromArc
            ? AppColors.midnightNavy.withValues(alpha: 0.82)
            : AppColors.cosmicBlue.withValues(alpha: 0.82),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(AppRadius.lg),
          topRight: const Radius.circular(AppRadius.lg),
          bottomLeft: Radius.circular(fromArc ? 6 : AppRadius.lg),
          bottomRight: Radius.circular(fromArc ? AppRadius.lg : 6),
        ),
        border: Border.all(
          color: fromArc
              ? AppColors.skyBlue.withValues(alpha: 0.18)
              : AppColors.skyBlue.withValues(alpha: 0.34),
        ),
        boxShadow: AppShadows.glassCard,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.white,
          height: 1.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: fromArc
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fromArc) ...[
            ArcWidget(emotion: emotion, size: 54, showSpeechBubble: false),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _ArcThinkingBubble extends StatelessWidget {
  const _ArcThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return const _ArcMessageBubble(
      text: '星図を読んでいるよ...',
      fromArc: true,
      emotion: ArcEmotion.serious,
    );
  }
}

class _ArcActionCard extends StatelessWidget {
  const _ArcActionCard({required this.onQuickAction});

  final ValueChanged<String> onQuickAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.midnightNavy.withValues(alpha: 0.80),
        borderRadius: AppRadius.glassCard,
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.22)),
        boxShadow: AppShadows.glassCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '今日の航路をArcに相談する',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _QuickAction(
                label: '次のMissionを選ぶ',
                onTap: () => onQuickAction('次のMissionを一緒に選んで。'),
              ),
              _QuickAction(
                label: 'Trailを振り返る',
                onTap: () => onQuickAction('最近のTrailを踏まえて振り返りたい。'),
              ),
              _QuickAction(
                label: '不安をほどく',
                onTap: () => onQuickAction('今の不安を小さな一歩に分けたい。'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArcCommandCenterCard extends StatelessWidget {
  const _ArcCommandCenterCard({
    required this.activeQuestCount,
    required this.missionCount,
    required this.trailCount,
    required this.onOpenQuest,
    required this.onCreateQuest,
    required this.onOpenTrail,
    required this.onHorizon,
  });

  final int activeQuestCount;
  final int missionCount;
  final int trailCount;
  final VoidCallback onOpenQuest;
  final VoidCallback onCreateQuest;
  final VoidCallback onOpenTrail;
  final VoidCallback onHorizon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.midnightNavy.withValues(alpha: 0.90),
            AppColors.cosmicBlue.withValues(alpha: 0.34),
            AppColors.gold.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.glassCard,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
        boxShadow: AppShadows.goldGlow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ArcWidget(
                emotion: ArcEmotion.support,
                size: 96,
                showSpeechBubble: false,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '旅の司令室',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Quest、Mission、Trailをつないで、次の一歩を一緒に見つける場所です。',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.parchment,
                        height: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _CommandMetric(label: 'Quest', value: '$activeQuestCount'),
              _CommandMetric(label: 'Mission', value: '$missionCount'),
              _CommandMetric(label: 'Trail', value: '$trailCount'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                onPressed: onCreateQuest,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('ArcとQuestを考える'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenQuest,
                icon: const Icon(Icons.explore_outlined),
                label: const Text('Questを見る'),
              ),
              OutlinedButton.icon(
                onPressed: onHorizon,
                icon: const Icon(Icons.public),
                label: const Text('Horizon'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommandMetric extends StatelessWidget {
  const _CommandMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 94,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.deepNavy.withValues(alpha: 0.46),
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.gold,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.parchment,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcEmotionTimelineCard extends StatelessWidget {
  const _ArcEmotionTimelineCard({required this.events});

  final List<ArcEmotionEvent> events;

  @override
  Widget build(BuildContext context) {
    final visibleEvents = events.take(5).toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.midnightNavy.withValues(alpha: 0.80),
        borderRadius: AppRadius.glassCard,
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.22)),
        boxShadow: AppShadows.glassCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Arc Emotion Timeline',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Arcが旅の感情を少しずつ覚えていきます。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.parchment,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (visibleEvents.isEmpty)
            Row(
              children: [
                const ArcWidget(
                  emotion: ArcEmotion.normal,
                  size: 42,
                  showSpeechBubble: false,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'まだ静かな星図です。Quest、Mission、Trailを進めると、Arcの表情もここに残ります。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.white,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            )
          else
            ...visibleEvents.map(
              (event) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _ArcEmotionTimelineTile(event: event),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArcEmotionTimelineTile extends StatelessWidget {
  const _ArcEmotionTimelineTile({required this.event});

  final ArcEmotionEvent event;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ArcWidget(emotion: event.emotion, size: 38, showSpeechBubble: false),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      event.sourceType.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _formatTime(event.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.parchment,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                event.reason,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.white,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 42),
        backgroundColor: AppColors.cosmicBlue.withValues(alpha: 0.78),
        foregroundColor: AppColors.white,
      ),
      child: Text(label),
    );
  }
}

class _ShootingStarDivider extends StatelessWidget {
  const _ShootingStarDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Center(
        child: Icon(Icons.auto_awesome, color: AppColors.gold, size: 32),
      ),
    );
  }
}

class _ArcInputBar extends StatelessWidget {
  const _ArcInputBar({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.midnightNavy.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.24)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onSubmitted: (_) => onSend(),
                style: const TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  hintText: 'メッセージを入力...',
                  hintStyle: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.46),
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              onPressed: onSend,
              icon: const Icon(Icons.near_me, color: AppColors.gold),
              tooltip: '送信',
            ),
          ],
        ),
      ),
    );
  }
}

class _ArcQuestConfirmation {
  const _ArcQuestConfirmation({required this.input, required this.candidates});

  final String input;
  final List<ArcQuestCandidate> candidates;
}

class _ArcQuestCreationSheet extends StatefulWidget {
  const _ArcQuestCreationSheet();

  @override
  State<_ArcQuestCreationSheet> createState() => _ArcQuestCreationSheetState();
}

class _ArcQuestCreationSheetState extends State<_ArcQuestCreationSheet> {
  final _inputController = TextEditingController();
  final ArcQuestCreationService _service = const LocalArcQuestCreationService();
  ArcQuestDraft? _draft;
  bool _isGenerating = false;
  int _variation = 0;
  String? _error;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      setState(() => _error = '叶えたいことを、普段の言葉で教えてください。');
      return;
    }
    setState(() {
      _isGenerating = true;
      _error = null;
    });
    try {
      final draft = await _service.generate(
        input: input,
        variation: _variation++,
      );
      if (!mounted) return;
      setState(() => _draft = draft);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _draft = ArcQuestDraft(
          input: input,
          candidates: List.generate(
            3,
            (_) => ArcQuestCandidate(title: '新しいQuest'),
          ),
        );
        _error = '候補をうまく描けませんでした。入力は残してあるので、手動で整えられます。';
      });
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _confirm() {
    final draft = _draft;
    if (draft == null) return;
    final valid = draft.validCandidates;
    if (valid.isEmpty) {
      setState(() => _error = '保存するQuest名を1つ以上入力してください。');
      return;
    }
    Navigator.of(
      context,
    ).pop(_ArcQuestConfirmation(input: draft.input, candidates: valid));
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          top: AppSpacing.xl,
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Material(
          color: AppColors.midnightNavy,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.9,
            ),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                Row(
                  children: [
                    const ArcWidget(
                      emotion: ArcEmotion.support,
                      size: 72,
                      showSpeechBubble: false,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ArcとQuestを見つける',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const Text(
                            '叶えたいことや気になっていることを、そのまま話してね。',
                            style: TextStyle(color: AppColors.parchment),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: AppColors.white,
                      tooltip: '閉じる',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _inputController,
                  minLines: 3,
                  maxLines: 5,
                  enabled: !_isGenerating,
                  style: const TextStyle(color: AppColors.white),
                  decoration: const InputDecoration(
                    labelText: 'どんな未来を思い描いている？',
                    hintText: '例: いつか自分のサービスを世に出して、誰かの挑戦を支えたい',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: _isGenerating ? null : _generate,
                  icon: _isGenerating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_outlined),
                  label: Text(draft == null ? 'Quest候補を描く' : '候補を描き直す'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.warmGold),
                  ),
                ],
                if (draft != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    '候補を確認する',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    '名前の編集、並べ替え、追加・削除ができます。まだ保存はされません。',
                    style: TextStyle(color: AppColors.parchment),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: draft.candidates.length,
                    onReorderItem: (oldIndex, newIndex) {
                      setState(() => _draft = draft.move(oldIndex, newIndex));
                    },
                    itemBuilder: (context, index) {
                      final candidate = draft.candidates[index];
                      return Padding(
                        key: ValueKey(candidate.id),
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          children: [
                            ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.all(AppSpacing.sm),
                                child: Icon(
                                  Icons.drag_indicator,
                                  color: AppColors.parchment,
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextFormField(
                                initialValue: candidate.title,
                                style: const TextStyle(color: AppColors.white),
                                decoration: InputDecoration(
                                  labelText: 'Quest ${index + 1}',
                                ),
                                onChanged: (value) => setState(
                                  () => _draft = _draft?.update(
                                    candidate.id,
                                    value,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: draft.candidates.length <= 1
                                  ? null
                                  : () => setState(
                                      () => _draft = draft.remove(candidate.id),
                                    ),
                              icon: const Icon(Icons.remove_circle_outline),
                              color: AppColors.parchment,
                              tooltip: '候補を削除',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: draft.candidates.length >= 7
                          ? null
                          : () => setState(() => _draft = draft.add()),
                      icon: const Icon(Icons.add),
                      label: const Text('候補を追加'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: _confirm,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text('${draft.validCandidates.length}件のQuestを確定する'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
