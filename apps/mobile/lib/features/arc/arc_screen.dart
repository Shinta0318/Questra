import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../widgets/arc/arc_emotion.dart';
import '../../widgets/arc/arc_empty_state.dart';
import '../../widgets/arc/arc_widget.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../arc_memory/arc_memory_model.dart';
import '../arc_memory/arc_memory_providers.dart';
import '../auth/auth_controller.dart';
import '../mission/mission_controller.dart';
import '../mission/mission_model.dart';
import '../quest/quest_controller.dart';
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
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.adventure),
        child: SafeArea(
          child: Column(
            children: [
              const _ArcHeader(),
              Expanded(
                child: QuestraResponsiveListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.xl,
                    AppSpacing.xl,
                  ),
                  children: [
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
      ),
    );
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
