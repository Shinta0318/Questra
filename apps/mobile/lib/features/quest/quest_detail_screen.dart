import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/questra_colors.dart';
import '../../widgets/arc/arc_emotion.dart';
import '../../widgets/arc/arc_widget.dart';
import '../../widgets/questra_card.dart';
import '../../widgets/questra_primary_button.dart';
import '../arc/arc_celebration_service.dart';
import '../arc/arc_guidance_providers.dart';
import '../mission/mission_controller.dart';
import '../mission/mission_model.dart';
import '../trail/trail_controller.dart';
import '../trail/trail_model.dart';
import 'arc_quest_guide_controller.dart';
import 'arc_quest_guide_service.dart';
import 'quest_controller.dart';
import 'quest_guide_controller.dart';
import 'quest_guide_model.dart';
import 'quest_milestone_controller.dart';
import 'quest_milestone_model.dart';
import 'quest_model.dart';
import 'quest_providers.dart';

class QuestDetailScreen extends ConsumerWidget {
  const QuestDetailScreen({required this.questId, super.key});

  final String questId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questMatches = ref
        .watch(questControllerProvider)
        .where((quest) => quest.id == questId);
    final quest = questMatches.isEmpty ? null : questMatches.first;
    final guideState = ref.watch(questGuideControllerProvider);
    final arcGuideState = ref.watch(arcQuestGuideControllerProvider);
    final missions = ref
        .watch(missionControllerProvider)
        .where((mission) => mission.questId == questId)
        .toList();
    final trails = ref
        .watch(trailControllerProvider)
        .where((trail) => trail.questId == questId)
        .toList();

    if (quest == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quest Detail')),
        body: const Center(child: Text('星図の中でこのQuestを見つけられませんでした。')),
      );
    }

    final guides = guideState.guidesByQuest[questId] ?? _mockGuides(quest);
    final advice = guideState.adviceByQuest[questId] ?? _mockAdvice(quest);
    final starMap = guideState.starMapByQuest[questId] ?? _mockStarMap(quest);
    final storedMilestones =
        ref.watch(questMilestoneControllerProvider)[questId] ??
        const <QuestMilestone>[];
    final generatedMilestones = ref
        .watch(questMilestoneServiceProvider)
        .plan(quest: quest, guides: guides, missions: missions);
    final milestones = storedMilestones.isEmpty
        ? generatedMilestones
        : storedMilestones;

    return Scaffold(
      backgroundColor: QuestraColors.deepNavy,
      appBar: AppBar(title: const Text('Quest詳細')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            _QuestHeader(quest: quest),
            const SizedBox(height: 16),
            _ProgressSection(quest: quest),
            const SizedBox(height: 16),
            _MilestonesSection(
              milestones: milestones,
              isGeneratedPlan: storedMilestones.isEmpty,
            ),
            const SizedBox(height: 16),
            _ArcQuestGuidePanel(quest: quest, state: arcGuideState),
            const SizedBox(height: 16),
            _SectionTitle(number: 5, title: 'Guides'),
            const SizedBox(height: 12),
            ...guides.map(
              (guide) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _GuideCard(
                  quest: quest,
                  guide: guide,
                  advice: _firstAdvice(advice, guide.guideType),
                  starMap: starMap
                      .where((item) => item.guideType == guide.guideType)
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _MissionsSection(quest: quest, guides: guides, missions: missions),
            const SizedBox(height: 16),
            _TrailSection(quest: quest, missions: missions, trails: trails),
            const SizedBox(height: 16),
            _DreamBoardSection(quest: quest),
          ],
        ),
      ),
    );
  }
}

class _QuestHeader extends StatelessWidget {
  const _QuestHeader({required this.quest});

  final Quest quest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [QuestraColors.midnightNavy, QuestraColors.cosmicBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: QuestraColors.gold.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ArcWidget(
                emotion: ArcEmotion.serious,
                size: 78,
                showSpeechBubble: false,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1 Quest Header',
                      style: TextStyle(
                        color: QuestraColors.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      quest.title,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: QuestraColors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      quest.description,
                      style: const TextStyle(color: QuestraColors.parchment),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaPill(label: quest.category, icon: Icons.category_outlined),
              _MetaPill(label: quest.status.label, icon: Icons.flag_outlined),
              _MetaPill(
                label: quest.difficulty.label,
                icon: Icons.fitness_center_outlined,
              ),
              if (quest.targetDate != null)
                _MetaPill(
                  label: DateFormat.MMMd('ja').format(quest.targetDate!),
                  icon: Icons.event_outlined,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: QuestraPrimaryButton(
                  label: 'Questを編集',
                  onPressed: () =>
                      context.go('${AppRoutes.quest}/${quest.id}/edit'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.quest});

  final Quest quest;

  @override
  Widget build(BuildContext context) {
    final percent = (quest.progress.clamp(0, 1) * 100).round();

    return _SectionCard(
      number: 2,
      title: 'Progress',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: quest.progress.clamp(0, 1),
                    minHeight: 12,
                    backgroundColor: QuestraColors.cloud,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      QuestraColors.gold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: QuestraColors.deepNavy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Guide、Mission、Trailを進めるほどQuestの輪郭がはっきりします。'),
          if (quest.progress >= 0.85 && quest.status == QuestStatus.active) ...[
            const SizedBox(height: 12),
            ArcCelebrationCard(
              moment: const ArcCelebrationService().build(
                event: ArcCelebrationEvent.questProgress,
                subject: quest.title,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MilestonesSection extends ConsumerWidget {
  const _MilestonesSection({
    required this.milestones,
    required this.isGeneratedPlan,
  });

  final List<QuestMilestone> milestones;
  final bool isGeneratedPlan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SectionCard(
      number: 3,
      title: 'Milestones',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Questを小さな到達点へ分けて、現在地と次の一歩を見えるようにします。'),
          const SizedBox(height: 12),
          if (isGeneratedPlan)
            OutlinedButton.icon(
              onPressed: () => ref
                  .read(questMilestoneControllerProvider.notifier)
                  .saveGeneratedPlan(milestones),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Milestoneを保存'),
            ),
          if (isGeneratedPlan) const SizedBox(height: 12),
          ...milestones.map(
            (milestone) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MilestoneTile(milestone: milestone),
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneTile extends ConsumerWidget {
  const _MilestoneTile({required this.milestone});

  final QuestMilestone milestone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final percent = (milestone.progress.clamp(0, 1) * 100).round();
    final nextStatus = ref
        .read(questMilestoneServiceProvider)
        .nextStatus(milestone.status);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: QuestraColors.cosmicBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: QuestraColors.cosmicBlue.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor:
                    milestone.status == QuestMilestoneStatus.completed
                    ? QuestraColors.gold
                    : QuestraColors.cosmicBlue,
                child: Text(
                  '${milestone.sortOrder + 1}',
                  style: const TextStyle(
                    color: QuestraColors.deepNavy,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      milestone.title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(milestone.description),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ActionChip(label: milestone.status.label),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: milestone.progress.clamp(0, 1),
              minHeight: 8,
              backgroundColor: QuestraColors.cloud,
              valueColor: const AlwaysStoppedAnimation<Color>(
                QuestraColors.gold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$percent%',
                style: const TextStyle(
                  color: QuestraColors.slate,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => ref
                    .read(questMilestoneControllerProvider.notifier)
                    .updateStatus(milestone, nextStatus),
                icon: const Icon(Icons.sync_alt_outlined),
                label: Text('${nextStatus.label}へ'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArcQuestGuidePanel extends ConsumerWidget {
  const _ArcQuestGuidePanel({required this.quest, required this.state});

  final Quest quest;
  final ArcQuestGuideState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guide = state.guideFor(quest.id);
    final isLoading = state.isLoading(quest.id);
    final error = state.errorFor(quest.id);

    return _SectionCard(
      number: 4,
      title: 'Arc Guide',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading) ...[
            const ArcWidget(
              emotion: ArcEmotion.serious,
              size: 70,
              message: '航路を読んでいます。目的地までの最初の星を探しているところです。',
            ),
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ] else if (guide == null) ...[
            if (error != null) ...[
              ArcWidget(
                emotion: ArcEmotion.worried,
                size: 70,
                message: '星雲が少し濃いみたい。今は手動でMissionを作る航路に切り替えられます。',
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: const TextStyle(color: QuestraColors.slate),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ] else
              const Text('ArcがこのQuestの進め方と最初のMission候補をまとめます。'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ref
                  .read(arcQuestGuideControllerProvider.notifier)
                  .generateForQuest(quest),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Arc Guideを生成'),
            ),
          ] else ...[
            ArcWidget(
              emotion: ArcEmotion.support,
              size: 70,
              message: guide.encouragement,
            ),
            const SizedBox(height: 14),
            _GuideTextBlock(title: 'Questの要約', body: guide.summary),
            const SizedBox(height: 10),
            _GuideTextBlock(title: '達成までの進め方', body: guide.path),
            const SizedBox(height: 10),
            _GuideTextBlock(title: '注意点', body: guide.cautions),
            const SizedBox(height: 16),
            Text(
              '最初のMission候補',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            ...guide.missionCandidates.map(
              (candidate) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MissionCandidateCard(
                  quest: quest,
                  candidate: candidate,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => ref
                  .read(arcQuestGuideControllerProvider.notifier)
                  .generateForQuest(quest),
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('Guideを再生成'),
            ),
          ],
        ],
      ),
    );
  }
}

class _GuideTextBlock extends StatelessWidget {
  const _GuideTextBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: QuestraColors.cosmicBlue,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(body),
      ],
    );
  }
}

class _MissionCandidateCard extends ConsumerWidget {
  const _MissionCandidateCard({required this.quest, required this.candidate});

  final Quest quest;
  final ArcMissionCandidate candidate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: QuestraColors.cosmicBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: QuestraColors.cosmicBlue.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _guideIcon(candidate.guideType),
                color: _guideColor(candidate.guideType),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  candidate.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(candidate.description),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _ActionChip(label: candidate.guideType.japaneseLabel),
              _ActionChip(label: candidate.difficulty.japaneseLabel),
              OutlinedButton.icon(
                onPressed: () {
                  ref
                      .read(missionControllerProvider.notifier)
                      .addMissionDraft(
                        quest: quest,
                        title: candidate.title,
                        description: candidate.description,
                        guideType: candidate.guideType,
                        difficulty: candidate.difficulty,
                      );
                  showArcCelebrationSnackBar(
                    context,
                    ref
                        .read(arcCelebrationServiceProvider)
                        .build(
                          event: ArcCelebrationEvent.missionStarted,
                          subject: candidate.title,
                        ),
                  );
                },
                icon: const Icon(Icons.flag_outlined),
                label: const Text('採用'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuideCard extends ConsumerWidget {
  const _GuideCard({
    required this.quest,
    required this.guide,
    required this.advice,
    required this.starMap,
  });

  final Quest quest;
  final QuestGuide guide;
  final ArcAdvice? advice;
  final List<StarMapItem> starMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: QuestraColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _guideColor(guide.guideType).withValues(alpha: 0.34),
        ),
        boxShadow: [
          BoxShadow(
            color: _guideColor(guide.guideType).withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _guideColor(guide.guideType).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _guideIcon(guide.guideType),
                  color: _guideColor(guide.guideType),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guide.guideType.japaneseLabel,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      guide.guideType.label,
                      style: const TextStyle(
                        color: QuestraColors.slate,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(guide.description),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: guide.suggestedActions
                .map((action) => _ActionChip(label: action))
                .toList(),
          ),
          if (advice != null) ...[
            const SizedBox(height: 14),
            ArcWidget(
              emotion: advice!.emotion,
              size: 64,
              message: advice!.adviceText,
            ),
          ],
          if (starMap.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Dream Board素材: ${starMap.first.title}',
              style: const TextStyle(
                color: QuestraColors.cosmicBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              ref
                  .read(missionControllerProvider.notifier)
                  .generateMission(quest: quest, guide: guide, advice: advice);
              showArcCelebrationSnackBar(
                context,
                ref
                    .read(arcCelebrationServiceProvider)
                    .build(
                      event: ArcCelebrationEvent.missionStarted,
                      subject: guide.guideType.japaneseLabel,
                    ),
              );
            },
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Missionを生成'),
          ),
        ],
      ),
    );
  }
}

class _MissionsSection extends StatelessWidget {
  const _MissionsSection({
    required this.quest,
    required this.guides,
    required this.missions,
  });

  final Quest quest;
  final List<QuestGuide> guides;
  final List<Mission> missions;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      number: 6,
      title: 'Missions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (missions.isEmpty)
            const Text('Guideから今日できる小さなMissionを生成できます。')
          else
            ...missions.map(
              (mission) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      mission.status == MissionStatus.completed
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: QuestraColors.gold,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${mission.title} / ${mission.guideType.japaneseLabel}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            '分解元: ${guides.map((guide) => guide.guideType.japaneseLabel).join('・')}',
            style: const TextStyle(color: QuestraColors.slate),
          ),
        ],
      ),
    );
  }
}

class _TrailSection extends ConsumerWidget {
  const _TrailSection({
    required this.quest,
    required this.missions,
    required this.trails,
  });

  final Quest quest;
  final List<Mission> missions;
  final List<Trail> trails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trailSteps = [
      'Questを作成',
      '6つのGuideへ分解',
      'Arc Adviceを確認',
      'Missionで今日の一歩へ',
    ];

    return _SectionCard(
      number: 7,
      title: 'Trail',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < trailSteps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: i == 0
                        ? QuestraColors.gold
                        : QuestraColors.cosmicBlue,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: QuestraColors.deepNavy,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(trailSteps[i])),
                ],
              ),
            ),
          if (trails.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...trails.map(
              (trail) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• ${trail.title} / ${trail.trailType.label}'),
              ),
            ),
          ],
          Text(
            'Trailは「${quest.title}」の進行ログとして育っていきます。',
            style: const TextStyle(color: QuestraColors.slate),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              final latestMission = missions.isEmpty ? null : missions.first;
              ref
                  .read(trailControllerProvider.notifier)
                  .addQuestTrail(
                    questId: quest.id,
                    missionId: latestMission?.id,
                    questTitle: quest.title,
                  );
              showArcCelebrationSnackBar(
                context,
                ref
                    .read(arcCelebrationServiceProvider)
                    .build(
                      event: ArcCelebrationEvent.trailRecorded,
                      subject: quest.title,
                    ),
              );
            },
            icon: const Icon(Icons.timeline_outlined),
            label: const Text('Trailを残す'),
          ),
        ],
      ),
    );
  }
}

class _DreamBoardSection extends StatelessWidget {
  const _DreamBoardSection({required this.quest});

  final Quest quest;

  @override
  Widget build(BuildContext context) {
    final items = ['理想の到達点', '参考になる星', '必要な道具', '出会いたい仲間'];

    return _SectionCard(
      number: 8,
      title: 'Dream Board',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('「${quest.title}」を叶えるための素材置き場です。'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) => _ActionChip(label: item)).toList(),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.number, required this.title});

  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$number $title',
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: QuestraColors.white,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.number,
    required this.title,
    required this.child,
  });

  final int number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return QuestraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$number $title', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: QuestraColors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: QuestraColors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: QuestraColors.gold, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: QuestraColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: QuestraColors.cosmicBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: QuestraColors.midnightNavy,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

ArcAdvice? _firstAdvice(List<ArcAdvice> advice, GuideType guideType) {
  for (final item in advice) {
    if (item.guideType == guideType) {
      return item;
    }
  }
  return null;
}

List<QuestGuide> _mockGuides(Quest quest) {
  return GuideType.values
      .map(
        (guideType) => QuestGuide(
          questId: quest.id,
          guideType: guideType,
          title: '${guideType.label}: ${quest.title}',
          description: _guideDescription(quest, guideType),
          suggestedActions: _guideActions(guideType),
        ),
      )
      .toList();
}

List<ArcAdvice> _mockAdvice(Quest quest) {
  return GuideType.values
      .map(
        (guideType) => ArcAdvice(
          questId: quest.id,
          guideType: guideType,
          adviceText: '${guideType.japaneseLabel}から一歩だけ選ぼう。小さく進めば星図は明るくなるよ。',
          emotion: guideType == GuideType.training
              ? ArcEmotion.support
              : ArcEmotion.normal,
        ),
      )
      .toList();
}

List<StarMapItem> _mockStarMap(Quest quest) {
  return GuideType.values
      .map(
        (guideType) => StarMapItem(
          questId: quest.id,
          guideType: guideType,
          title: '${guideType.japaneseLabel}の参考星',
          description: 'Dream Boardに保存できるmock素材です。',
          url: 'https://example.com/${guideType.name}',
          contentType: 'mock',
        ),
      )
      .toList();
}

String _guideDescription(Quest quest, GuideType guideType) {
  return switch (guideType) {
    GuideType.route => '目的地までの航路を描き、最初のチェックポイントを決めます。',
    GuideType.knowledge => '達成に必要な知識と、最初に調べるテーマを整理します。',
    GuideType.training => '初心者でも今日から練習できる小さな型に分けます。',
    GuideType.guild => '相談できるGuildの仲間、参加できる場所、質問の入口を探します。',
    GuideType.resource => '必要な道具、素材、時間、環境を準備します。',
    GuideType.opportunity => '広告や企業オファーではなく、学びや挑戦の機会を見つけます。',
  };
}

List<String> _guideActions(GuideType guideType) {
  return switch (guideType) {
    GuideType.route => ['ゴールを書く', '3つの通過点を決める', '次の一歩を選ぶ'],
    GuideType.knowledge => ['知らないことを列挙', '1つ読む', 'Arcに質問する'],
    GuideType.training => ['10分練習', '1回だけ試す', '難所をメモする'],
    GuideType.guild => ['相談相手を探す', 'Guildの場を見つける', '小さく質問する'],
    GuideType.resource => ['道具を1つ準備', '作業場所を整える', '詰まりを1つ消す'],
    GuideType.opportunity => ['イベントを探す', '挑戦枠を見る', '次の入口を保存する'],
  };
}

Color _guideColor(GuideType guideType) {
  return switch (guideType) {
    GuideType.route => QuestraColors.cosmicBlue,
    GuideType.knowledge => const Color(0xFF2FBF71),
    GuideType.training => QuestraColors.gold,
    GuideType.guild => const Color(0xFF7B61FF),
    GuideType.resource => const Color(0xFF1CB5E0),
    GuideType.opportunity => const Color(0xFFFF8A5B),
  };
}

IconData _guideIcon(GuideType guideType) {
  return switch (guideType) {
    GuideType.route => Icons.route_outlined,
    GuideType.knowledge => Icons.menu_book_outlined,
    GuideType.training => Icons.fitness_center_outlined,
    GuideType.guild => Icons.groups_outlined,
    GuideType.resource => Icons.inventory_2_outlined,
    GuideType.opportunity => Icons.auto_awesome_outlined,
  };
}

extension _GuideTypeJapaneseLabel on GuideType {
  String get japaneseLabel {
    return switch (this) {
      GuideType.route => '航路',
      GuideType.knowledge => '知識',
      GuideType.training => '鍛錬',
      GuideType.guild => '仲間',
      GuideType.resource => '準備',
      GuideType.opportunity => '機会',
    };
  }
}

extension _MissionDifficultyJapaneseLabel on MissionDifficulty {
  String get japaneseLabel {
    return switch (this) {
      MissionDifficulty.easy => 'やさしい',
      MissionDifficulty.normal => 'ふつう',
    };
  }
}
