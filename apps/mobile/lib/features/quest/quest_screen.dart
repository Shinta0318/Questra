import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/questra_colors.dart';
import '../../widgets/arc/arc_emotion.dart';
import '../../widgets/arc/arc_empty_state.dart';
import '../../widgets/arc/arc_widget.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/persistence_sync_banner.dart';
import '../arc/arc_concern_service.dart';
import '../arc/arc_guidance_providers.dart';
import '../auth/auth_controller.dart';
import '../mission/mission_controller.dart';
import '../mission/mission_model.dart';
import '../trail/trail_controller.dart';
import '../trail/trail_model.dart';
import 'quest_controller.dart';
import 'quest_model.dart';

class QuestScreen extends ConsumerWidget {
  const QuestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quests = ref.watch(questControllerProvider);
    final profile = ref.watch(authControllerProvider).profile;
    final missions = ref.watch(missionControllerProvider);
    final trails = ref.watch(trailControllerProvider);
    final syncState = ref.watch(questSyncControllerProvider);
    final activeQuests = quests
        .where((quest) => quest.status == QuestStatus.active)
        .toList();
    final focusQuest = activeQuests.isEmpty ? null : activeQuests.first;
    final dashboardMissions = focusQuest == null
        ? missions
        : missions
              .where((mission) => mission.questId == focusQuest.id)
              .toList(growable: false);
    final dashboardTrails = focusQuest == null
        ? trails
        : trails
              .where((trail) => trail.questId == focusQuest.id)
              .toList(growable: false);
    final arcExpression = ref
        .watch(arcExpressionEngineProvider)
        .resolveJourney(quests: quests, missions: missions, trails: trails);
    final concern = ref
        .watch(arcConcernServiceProvider)
        .evaluate(quests: quests, missions: missions, trails: trails);

    return Scaffold(
      backgroundColor: QuestraColors.deepNavy,
      appBar: AppBar(
        title: const Text('Quest一覧'),
        actions: [
          IconButton(
            tooltip: '新しいQuestを始める',
            onPressed: () => context.go('${AppRoutes.quest}/create'),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: QuestraResponsiveListView(
          onRefresh: profile == null
              ? null
              : () => ref
                    .read(questControllerProvider.notifier)
                    .loadForUser(profile.id),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            PersistenceSyncBanner(
              state: syncState,
              onDismiss: () =>
                  ref.read(questSyncControllerProvider.notifier).clear(),
            ),
            if (syncState.isActive) const SizedBox(height: 12),
            _QuestHero(
              activeCount: activeQuests.length,
              emotion: arcExpression.emotion,
              onCreateQuest: () => context.go('${AppRoutes.quest}/create'),
            ),
            if (concern != null) ...[
              const SizedBox(height: 16),
              _QuestConcernCard(concern: concern),
            ],
            const SizedBox(height: 16),
            _QuestProgressDashboard(
              quest: focusQuest,
              missions: dashboardMissions,
              trailCount: dashboardTrails.length,
              latestActivity: _latestActivity(
                dashboardMissions,
                dashboardTrails,
              ),
              onOpenQuest: focusQuest == null
                  ? () => context.go(AppRoutes.quest)
                  : () => context.go('${AppRoutes.quest}/${focusQuest.id}'),
            ),
            const SizedBox(height: 22),
            Text(
              '進行中のQuest',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: QuestraColors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (quests.isEmpty)
              ArcEmptyState(
                title: 'まだQuestがありません',
                message: '最初のQuestを灯すと、ArcがMissionとTrailへの航路を一緒に描きます。',
                actionLabel: 'Questを作成',
                icon: Icons.add_circle_outline,
                onAction: () => context.go('${AppRoutes.quest}/create'),
              )
            else
              ...quests.map(
                (quest) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _QuestCard(
                    quest: quest,
                    onTap: () => context.go('${AppRoutes.quest}/${quest.id}'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _latestActivity(List<Mission> missions, List<Trail> trails) {
    final latestMission = [...missions]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latestTrail = [...trails]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (latestTrail.isNotEmpty) {
      return '最近のTrail: ${latestTrail.first.title}';
    }
    if (latestMission.isNotEmpty) {
      return '最近のMission: ${latestMission.first.title}';
    }
    return 'まだ最近の活動はありません。最初のMissionから始めましょう。';
  }
}

class _QuestConcernCard extends StatelessWidget {
  const _QuestConcernCard({required this.concern});

  final ArcConcern concern;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: QuestraColors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: QuestraColors.gold.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: QuestraColors.gold.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ArcWidget(
            emotion: concern.emotion,
            size: 76,
            showSpeechBubble: false,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  concern.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(concern.message),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _openConcernTarget(context),
                  icon: const Icon(Icons.near_me_outlined),
                  label: Text(concern.actionLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openConcernTarget(BuildContext context) {
    if (concern.type == ArcConcernType.lowActivity) {
      context.go(AppRoutes.trail);
      return;
    }
    if (concern.questId != null) {
      context.go('${AppRoutes.quest}/${concern.questId}');
      return;
    }
    context.go(AppRoutes.quest);
  }
}

class _QuestHero extends StatelessWidget {
  const _QuestHero({
    required this.activeCount,
    required this.emotion,
    required this.onCreateQuest,
  });

  final int activeCount;
  final ArcEmotion emotion;
  final VoidCallback onCreateQuest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [QuestraColors.midnightNavy, QuestraColors.cosmicBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: QuestraColors.gold.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: QuestraColors.cosmicBlue.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          ArcWidget(emotion: emotion, size: 86, showSpeechBubble: false),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quest一覧',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: QuestraColors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '進行中のQuest $activeCount 件',
                  style: const TextStyle(
                    color: QuestraColors.parchment,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: onCreateQuest,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('新しいQuestを始める'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestProgressDashboard extends StatelessWidget {
  const _QuestProgressDashboard({
    required this.quest,
    required this.missions,
    required this.trailCount,
    required this.latestActivity,
    required this.onOpenQuest,
  });

  final Quest? quest;
  final List<Mission> missions;
  final int trailCount;
  final String latestActivity;
  final VoidCallback onOpenQuest;

  @override
  Widget build(BuildContext context) {
    final questProgress = ((quest?.progress ?? 0) * 100).round();
    final questMissions = quest == null
        ? missions
        : missions.where((mission) => mission.questId == quest!.id).toList();
    final completedMissions = questMissions
        .where((mission) => mission.status == MissionStatus.completed)
        .length;
    final arcComment = quest == null
        ? 'Questをひとつ選ぶと、進み方を一緒に見渡せるよ。'
        : '「${quest!.title}」は$questProgress%まで進んでいるよ。次は小さなMissionでTrailを増やそう。';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: QuestraColors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: QuestraColors.gold.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quest Dashboard',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _DashboardMetric(label: 'Progress', value: '$questProgress%'),
              _DashboardMetric(
                label: 'Missions',
                value: '$completedMissions/${questMissions.length}',
              ),
              _DashboardMetric(label: 'Trails', value: trailCount.toString()),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (quest?.progress ?? 0).clamp(0, 1),
              minHeight: 9,
              backgroundColor: QuestraColors.cloud,
              valueColor: const AlwaysStoppedAnimation<Color>(
                QuestraColors.gold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(latestActivity),
          const SizedBox(height: 8),
          Text(arcComment),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onOpenQuest,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Quest詳細へ'),
          ),
        ],
      ),
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: QuestraColors.deepNavy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.quest, required this.onTap});

  final Quest quest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progressPercent = (quest.progress.clamp(0, 1) * 100).round();

    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: QuestraColors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: QuestraColors.cosmicBlue.withValues(alpha: 0.20),
          ),
          boxShadow: [
            BoxShadow(
              color: QuestraColors.skyBlue.withValues(alpha: 0.14),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: QuestraColors.deepNavy,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.travel_explore,
                    color: QuestraColors.gold,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quest.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        quest.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: quest.progress.clamp(0, 1),
                      minHeight: 9,
                      backgroundColor: QuestraColors.cloud,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        QuestraColors.gold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$progressPercent%',
                  style: const TextStyle(
                    color: QuestraColors.deepNavy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuestPill(
                  icon: Icons.flag_outlined,
                  label: quest.status.label,
                  emphasized: quest.status == QuestStatus.active,
                ),
                _QuestPill(
                  icon: Icons.fitness_center_outlined,
                  label: quest.difficulty.label,
                ),
                _QuestPill(
                  icon: Icons.category_outlined,
                  label: quest.category,
                ),
                if (quest.targetDate != null)
                  _QuestPill(
                    icon: Icons.event_outlined,
                    label: DateFormat.MMMd('ja').format(quest.targetDate!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestPill extends StatelessWidget {
  const _QuestPill({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: emphasized
            ? QuestraColors.gold.withValues(alpha: 0.22)
            : QuestraColors.cosmicBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: emphasized
              ? QuestraColors.gold.withValues(alpha: 0.58)
              : QuestraColors.cosmicBlue.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: emphasized
                ? QuestraColors.deepNavy
                : QuestraColors.cosmicBlue,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: emphasized
                  ? QuestraColors.deepNavy
                  : QuestraColors.midnightNavy,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
