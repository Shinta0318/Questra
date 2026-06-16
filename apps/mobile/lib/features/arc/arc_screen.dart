import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/arc/arc_examples.dart';
import '../../widgets/questra_card.dart';
import '../auth/auth_controller.dart';
import '../arc_memory/arc_memory_model.dart';
import '../arc_memory/arc_memory_providers.dart';
import '../mission/mission_controller.dart';
import '../mission/mission_model.dart';
import '../quest/quest_controller.dart';
import '../quest/quest_model.dart';
import '../trail/trail_controller.dart';
import '../trail/trail_model.dart';
import 'arc_emotion.dart';
import 'arc_guidance_providers.dart';
import 'arc_guidance_service.dart';
import 'arc_journey_context.dart';
import 'arc_widget.dart';

class ArcScreen extends ConsumerStatefulWidget {
  const ArcScreen({super.key});

  @override
  ConsumerState<ArcScreen> createState() => _ArcScreenState();
}

class _ArcScreenState extends ConsumerState<ArcScreen> {
  final _messageController = TextEditingController();
  final List<_ArcChatMessage> _messages = [
    const _ArcChatMessage(
      author: _ArcChatAuthor.arc,
      text: '次に向かいたい星を聞かせて。急がなくて大丈夫。',
    ),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quests = ref.watch(questControllerProvider);
    final missions = ref.watch(missionControllerProvider);
    final trails = ref.watch(trailControllerProvider);
    final guidance = ref
        .watch(arcGuidanceServiceProvider)
        .build(quests: quests, missions: missions, trails: trails);
    final journeyContext = ArcJourneyContext.fromJourney(
      quests: quests,
      trails: trails,
    );
    final memories = ref.watch(visibleArcMemoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Arc Chat')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const QuestraCard(
              child: ArcWidget(
                emotion: ArcEmotion.normal,
                message:
                    'I remember your route. Let us choose the next Mission with care.',
              ),
            ),
            const SizedBox(height: 16),
            _ArcChatCard(
              messages: _messages,
              controller: _messageController,
              onSubmit: () => _sendMessage(
                quests: quests,
                missions: missions,
                trails: trails,
                guidance: guidance,
                journeyContext: journeyContext,
              ),
            ),
            const SizedBox(height: 16),
            QuestraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Journey Context',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(journeyContext.guidance),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          '${journeyContext.activeQuestCount} active Quests',
                        ),
                      ),
                      Chip(label: Text('${journeyContext.trailCount} Trails')),
                      if (journeyContext.focusQuestTitle != null)
                        Chip(label: Text(journeyContext.focusQuestTitle!)),
                      if (journeyContext.latestTrailTitle != null)
                        Chip(label: Text(journeyContext.latestTrailTitle!)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ArcGuidanceCard(guidance: guidance),
            const SizedBox(height: 16),
            memories.when(
              data: (items) => _ArcMemoryContextCard(memories: items),
              loading: () => const QuestraCard(
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Loading Arc memories...'),
                  ],
                ),
              ),
              error: (error, stackTrace) => QuestraCard(
                child: Text('Arc memory context is unavailable: $error'),
              ),
            ),
            const SizedBox(height: 16),
            Text('Arc Guidance', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const ArcHomeExample(),
            const SizedBox(height: 12),
            const ArcChatExample(),
            const SizedBox(height: 16),
            Text('Arc Moods', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: ArcEmotion.values
                  .map(
                    (emotion) => SizedBox(
                      width: 150,
                      child: QuestraCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            ArcWidget(emotion: emotion, size: 72),
                            const SizedBox(height: 8),
                            Text(
                              emotion.label,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage({
    required List<Quest> quests,
    required List<Mission> missions,
    required List<Trail> trails,
    required ArcGuidance guidance,
    required ArcJourneyContext journeyContext,
  }) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }
    _messageController.clear();

    final reply = _buildArcReply(
      text: text,
      quests: quests,
      missions: missions,
      trails: trails,
      guidance: guidance,
      journeyContext: journeyContext,
    );
    setState(() {
      _messages
        ..add(_ArcChatMessage(author: _ArcChatAuthor.user, text: text))
        ..add(_ArcChatMessage(author: _ArcChatAuthor.arc, text: reply));
    });

    final profile = ref.read(authControllerProvider).profile;
    if (profile == null) {
      return;
    }
    await ref
        .read(memoryExtractionServiceProvider)
        .extractAndSave(
          MemoryExtractionEvent(
            userId: profile.id,
            sourceType: ArcMemorySourceType.arcChat,
            text: text,
            title: 'Arc Chat memory',
            metadata: {'surface': 'arc_chat'},
          ),
        );
    ref.invalidate(visibleArcMemoriesProvider);
  }

  String _buildArcReply({
    required String text,
    required List<Quest> quests,
    required List<Mission> missions,
    required List<Trail> trails,
    required ArcGuidance guidance,
    required ArcJourneyContext journeyContext,
  }) {
    final lower = text.toLowerCase();
    final activeQuests = quests
        .where((quest) => quest.status == QuestStatus.active)
        .toList();
    final openMissions =
        missions
            .where((mission) => mission.status == MissionStatus.todo)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (activeQuests.isEmpty) {
      return 'まずQuestをひとつ星にしよう。願いを一文で置けたら、そこから小さなMissionを一緒に選べるよ。';
    }
    if (lower.contains('mission') ||
        lower.contains('次') ||
        lower.contains('今日')) {
      if (openMissions.isEmpty) {
        return guidance.nextMission;
      }
      return guidance.nextMission;
    }
    if (lower.contains('trail') || lower.contains('残')) {
      if (trails.isEmpty) {
        return '最初のTrailは、完璧な記録じゃなくて大丈夫。Missionを終えたあとに「何が少し進んだか」を一行で残そう。';
      }
      return guidance.reflectionFeedback;
    }
    if (lower.contains('quest') || lower.contains('進捗')) {
      return guidance.questComment;
    }
    return journeyContext.focusQuestTitle == null
        ? '君の今の航路を見ながら、次の一歩を小さくしよう。Quest、Mission、Trailのどこを整えたい？'
        : '今は「${journeyContext.focusQuestTitle}」が明るく見えているよ。次はMissionをひとつ選び、終えたらTrailに残そう。';
  }
}

class _ArcMemoryContextCard extends StatelessWidget {
  const _ArcMemoryContextCard({required this.memories});

  final List<ArcMemory> memories;

  @override
  Widget build(BuildContext context) {
    final visibleMemories = memories.take(3).toList(growable: false);

    return QuestraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Arc Memories', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (visibleMemories.isEmpty)
            const Text(
              'No visible memories yet. Arc will remember meaningful journey moments here.',
            )
          else
            ...visibleMemories.map(
              (memory) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memory.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(memory.content),
                    const SizedBox(height: 2),
                    Text(
                      '${memory.memoryType.storageKey} / ${memory.sourceType.storageKey}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArcGuidanceCard extends StatelessWidget {
  const _ArcGuidanceCard({required this.guidance});

  final ArcGuidance guidance;

  @override
  Widget build(BuildContext context) {
    return QuestraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contextual Guidance',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _GuidanceLine(
            icon: Icons.flag_outlined,
            label: 'Quest',
            text: guidance.questComment,
          ),
          const SizedBox(height: 10),
          _GuidanceLine(
            icon: Icons.check_circle_outline,
            label: 'Next Mission',
            text: guidance.nextMission,
          ),
          const SizedBox(height: 10),
          _GuidanceLine(
            icon: Icons.auto_awesome,
            label: 'Reflection',
            text: guidance.reflectionFeedback,
          ),
        ],
      ),
    );
  }
}

class _GuidanceLine extends StatelessWidget {
  const _GuidanceLine({
    required this.icon,
    required this.label,
    required this.text,
  });

  final IconData icon;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(text),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArcChatCard extends StatelessWidget {
  const _ArcChatCard({
    required this.messages,
    required this.controller,
    required this.onSubmit,
  });

  final List<_ArcChatMessage> messages;
  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return QuestraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Talk With Arc', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...messages.take(6).map(_ArcMessageBubble.new),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  decoration: const InputDecoration(
                    labelText: 'Arcに話す',
                    hintText: '今日のMissionを相談する',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => onSubmit(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Send to Arc',
                onPressed: onSubmit,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArcMessageBubble extends StatelessWidget {
  const _ArcMessageBubble(this.message);

  final _ArcChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isArc = message.author == _ArcChatAuthor.arc;
    return Align(
      alignment: isArc ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isArc ? const Color(0xFFEAF4FF) : const Color(0xFFFFF4D1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(message.text),
      ),
    );
  }
}

enum _ArcChatAuthor { arc, user }

class _ArcChatMessage {
  const _ArcChatMessage({required this.author, required this.text});

  final _ArcChatAuthor author;
  final String text;
}
