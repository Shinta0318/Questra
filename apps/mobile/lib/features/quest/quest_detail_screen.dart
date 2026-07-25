// ignore_for_file: unused_element

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/questra_colors.dart';
import '../../core/validation/input_validators.dart';
import '../../widgets/arc/arc_emotion.dart';
import '../../widgets/arc/arc_widget.dart';
import '../../widgets/forms/questra_field_label.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/questra_card.dart';
import '../../widgets/questra_primary_button.dart';
import '../arc/arc_celebration_service.dart';
import '../arc/arc_guidance_providers.dart';
import '../challenge_graph/challenge_graph_preview_service.dart';
import '../dream_board/dream_board_controller.dart';
import '../dream_board/dream_board_model.dart';
import '../enterprise_support/quest_support_boundary_service.dart';
import '../mission/mission_controller.dart';
import '../mission/mission_contract_service.dart';
import '../mission/mission_model.dart';
import '../mission/mission_plan_draft.dart';
import '../trail/trail_controller.dart';
import '../trail/trail_model.dart';
import 'arc_quest_guide_controller.dart';
import 'arc_quest_guide_service.dart';
import 'adaptive_route_service.dart';
import 'quest_controller.dart';
import 'quest_canvas_service.dart';
import 'quest_guide_model.dart';
import 'quest_milestone_controller.dart';
import 'quest_milestone_model.dart';
import 'quest_dna_snapshot.dart';
import 'quest_model.dart';
import 'quest_progress_service.dart';
import 'quest_providers.dart';
import 'quest_planning_feedback_repository.dart';
import 'route_replanning_controller.dart';
import 'route_replanning_model.dart';
import 'quest_theme_card.dart';

const _missionPlanUuid = Uuid();

class QuestDetailScreen extends ConsumerWidget {
  const QuestDetailScreen({required this.questId, super.key});

  final String questId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questMatches = ref
        .watch(questControllerProvider)
        .where((quest) => quest.id == questId);
    final quest = questMatches.isEmpty ? null : questMatches.first;
    final arcGuideState = ref.watch(arcQuestGuideControllerProvider);
    final pendingRouteProposal = ref.watch(
      routeReplanningControllerProvider.select((state) => state[questId]),
    );
    final missions = ref
        .watch(missionControllerProvider)
        .where((mission) => mission.questId == questId)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final questTrails = ref
        .watch(trailControllerProvider)
        .where((trail) => trail.questId == questId)
        .toList(growable: false);

    if (quest == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quest Detail')),
        body: const Center(child: Text('星図の中でこのQuestを見つけられませんでした。')),
      );
    }

    return Scaffold(
      backgroundColor: QuestraColors.deepNavy,
      appBar: AppBar(title: const Text('Quest詳細')),
      body: SafeArea(
        child: QuestraResponsiveListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            _QuestHeader(
              quest: quest,
              onEdit: () => _showQuestEditDialog(context, ref, quest),
            ),
            const SizedBox(height: 16),
            _ProgressSection(quest: quest, missions: missions),
            const SizedBox(height: 16),
            _QuestCanvasCard(
              snapshot: QuestCanvasService.build(
                quest: quest,
                missions: missions,
                trails: questTrails,
              ),
            ),
            const SizedBox(height: 16),
            _QuestEvaluationAndRouteCard(
              quest: quest,
              missions: missions,
              isLoading: arcGuideState.isLoading(quest.id),
              pendingProposal: pendingRouteProposal,
            ),
            const SizedBox(height: 16),
            _ArcQuestGuidePanel(quest: quest, state: arcGuideState),
            const SizedBox(height: 16),
            _MissionsSection(quest: quest, missions: missions),
          ],
        ),
      ),
    );
  }
}

class _QuestCanvasCard extends StatelessWidget {
  const _QuestCanvasCard({required this.snapshot});

  final QuestCanvasSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return QuestraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_outlined, color: QuestraColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Quest Canvas',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            snapshot.isGrowing
                ? 'Arcとの会話やTrailから、このQuestの航路が育っています。'
                : '最初のMissionを追加すると、航路の全体像がここに現れます。',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CanvasMetric(
                icon: Icons.route_outlined,
                label: '航路',
                value:
                    '${snapshot.openMissionCount} / ${snapshot.missionCount}',
              ),
              _CanvasMetric(
                icon: Icons.menu_book_outlined,
                label: '参考',
                value: '${snapshot.knowledgeCount}',
              ),
              _CanvasMetric(
                icon: Icons.psychology_outlined,
                label: 'スキル',
                value: '${snapshot.skillThemes.length}',
              ),
              _CanvasMetric(
                icon: Icons.shield_outlined,
                label: '注意',
                value: '${snapshot.riskCount}',
              ),
              _CanvasMetric(
                icon: Icons.handshake_outlined,
                label: '支援',
                value: '${snapshot.supportHintCount}',
              ),
              _CanvasMetric(
                icon: Icons.auto_stories_outlined,
                label: '記録',
                value: '${snapshot.trailCount}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CanvasMetric extends StatelessWidget {
  const _CanvasMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value',
      child: Container(
        constraints: const BoxConstraints(minWidth: 104),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: QuestraColors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17),
            const SizedBox(width: 6),
            Text('$label $value'),
          ],
        ),
      ),
    );
  }
}

class _QuestEvaluationAndRouteCard extends ConsumerWidget {
  const _QuestEvaluationAndRouteCard({
    required this.quest,
    required this.missions,
    required this.isLoading,
    required this.pendingProposal,
  });

  final Quest quest;
  final List<Mission> missions;
  final bool isLoading;
  final RouteChangeProposal? pendingProposal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evaluation = quest.evaluation;
    final proposal = AdaptiveRouteService.evaluate(
      quest: quest,
      missions: missions,
    );
    return QuestraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Arcの航路評価',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (evaluation == null)
            const Text('Missionを提案すると、難易度と期間をArcが評価します。')
          else ...[
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(evaluation.difficultyStars),
                Text(evaluation.durationLabel),
                Text('Mission ${evaluation.estimatedMissionCount}件'),
                if (evaluation.estimatedCostLabel != null)
                  Text(evaluation.estimatedCostLabel!),
              ],
            ),
            if (evaluation.rationale.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(evaluation.rationale),
            ],
            const SizedBox(height: 6),
            Text(
              '評価更新 ${DateFormat('yyyy/MM/dd HH:mm').format(evaluation.evaluatedAt.toLocal())}',
              style: const TextStyle(fontSize: 12, color: QuestraColors.slate),
            ),
          ],
          if (proposal != null) ...[
            const Divider(height: 24),
            Text(
              proposal.title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(proposal.message),
            if (proposal.recommendedTargetDate != null) ...[
              const SizedBox(height: 6),
              Text(
                '推奨期限: ${DateFormat('yyyy/MM').format(proposal.recommendedTargetDate!)}',
              ),
            ],
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isLoading
                ? null
                : () => _reviewRoute(
                      context,
                      ref,
                      quest,
                      missions,
                      existing: pendingProposal,
                    ),
            icon: Icon(
              proposal == null
                  ? Icons.analytics_outlined
                  : Icons.route_outlined,
            ),
            label: Text(
              pendingProposal != null
                  ? 'Arcからの提案を確認'
                  : proposal == null
                      ? 'AI評価を更新'
                      : '航路の再提案を確認',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '完了済みMissionや期限は自動で変更されません。',
            style: TextStyle(fontSize: 12, color: QuestraColors.slate),
          ),
        ],
      ),
    );
  }
}

Future<void> _reviewRoute(
  BuildContext context,
  WidgetRef ref,
  Quest quest,
  List<Mission> missions, {
  RouteChangeProposal? existing,
}) async {
  final proposal = existing ??
      await ref
          .read(routeReplanningControllerProvider.notifier)
          .review(quest, missions);
  if (!context.mounted) return;
  if (proposal == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('今は航路を変更する必要はなさそうです。')),
    );
    return;
  }
  final selected = proposal.items.map((item) => item.id).toSet();
  final result = await showDialog<_RouteReviewResult>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Arcから航路更新の提案'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(proposal.summary),
                const SizedBox(height: 8),
                Text(
                  '提案の確度 ${(proposal.confidence * 100).round()}%',
                  style:
                      const TextStyle(fontSize: 12, color: QuestraColors.slate),
                ),
                const Divider(height: 24),
                for (final item in proposal.items)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selected.contains(item.id),
                    onChanged: (value) => setState(() {
                      if (value ?? false) {
                        selected.add(item.id);
                      } else {
                        selected.remove(item.id);
                      }
                    }),
                    title: Text(item.title),
                    subtitle: Text(
                      '${item.reason}\n${_routeDiffLabel(item)}',
                    ),
                    isThreeLine: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                const SizedBox(height: 6),
                const Text(
                  '承認するまでMissionや期限は変わりません。削除を含む変更は常に個別確認します。',
                  style: TextStyle(fontSize: 12, color: QuestraColors.slate),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_RouteReviewResult.reject),
            child: const Text('今回は変更しない'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_RouteReviewResult.later),
            child: const Text('あとで確認'),
          ),
          FilledButton(
            onPressed: selected.isEmpty
                ? null
                : () =>
                    Navigator.of(dialogContext).pop(_RouteReviewResult.accept),
            child: const Text('選んだ変更を反映'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted ||
      result == null ||
      result == _RouteReviewResult.later) {
    return;
  }
  if (result == _RouteReviewResult.reject) {
    await ref.read(routeReplanningControllerProvider.notifier).reject(proposal);
    return;
  }
  await ref
      .read(routeReplanningControllerProvider.notifier)
      .accept(quest, missions, proposal, selected);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('承認した内容で航路を更新しました。'),
      action: SnackBarAction(
        label: '元に戻す',
        onPressed: () => unawaited(
          ref
              .read(routeReplanningControllerProvider.notifier)
              .undo(proposal.id),
        ),
      ),
    ),
  );
}

String _routeDiffLabel(RouteChangeItem item) {
  final before = item.beforeData.entries
      .map((entry) => '${entry.key}: ${entry.value ?? "なし"}')
      .join(' / ');
  final after = item.afterData.entries
      .map((entry) => '${entry.key}: ${entry.value ?? "なし"}')
      .join(' / ');
  return '変更前 ${before.isEmpty ? "なし" : before}\n変更後 ${after.isEmpty ? "なし" : after}';
}

enum _RouteReviewResult { accept, reject, later }

Future<void> _showQuestEditDialog(
  BuildContext context,
  WidgetRef ref,
  Quest quest,
) async {
  final titleController = TextEditingController(text: quest.title);
  final descriptionController = TextEditingController(text: quest.description);
  final formKey = GlobalKey<FormState>();
  final shouldSave = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Questを編集'),
      content: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QuestraFieldLabel(
                label: 'Questの名前',
                required: true,
                child: TextFormField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(),
                  maxLength: InputLimits.questTitle,
                  validator: (value) => InputValidators.requiredText(
                    value,
                    fieldName: 'Quest名',
                    maxLength: InputLimits.questTitle,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              QuestraFieldLabel(
                label: '叶えたい理由・相談内容',
                child: TextFormField(
                  controller: descriptionController,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(),
                  maxLength: InputLimits.questDescription,
                  validator: (value) => InputValidators.optionalText(
                    value,
                    fieldName: '説明',
                    maxLength: InputLimits.questDescription,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(true);
            }
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
  if (shouldSave == true && titleController.text.trim().isNotEmpty) {
    ref.read(questControllerProvider.notifier).update(
          quest.copyWith(
            title: titleController.text.trim(),
            description: descriptionController.text.trim(),
          ),
        );
  }
  titleController.dispose();
  descriptionController.dispose();
}

class _QuestHeader extends StatelessWidget {
  const _QuestHeader({required this.quest, required this.onEdit});

  final Quest quest;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = const QuestThemeResolver().resolve(quest);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: theme.backgroundGradient,
        border: Border.all(color: theme.accent.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ArcWidget(
                emotion: ArcEmotion.support,
                size: 78,
                showSpeechBubble: false,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(theme.icon, color: theme.accent, size: 18),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            theme.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.accent,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            quest.title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(color: QuestraColors.white),
                          ),
                        ),
                        IconButton(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined),
                          color: QuestraColors.white,
                          tooltip: 'Questを編集',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      quest.description,
                      style: const TextStyle(color: QuestraColors.parchment),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Arc: ${theme.arcHint}',
                      style: const TextStyle(
                        color: QuestraColors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
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
              _MetaPill(label: theme.dnaLabel, icon: Icons.category_outlined),
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

class _QuestJourneyOverview extends ConsumerWidget {
  const _QuestJourneyOverview({
    required this.quest,
    required this.missions,
    required this.trails,
    required this.hasArcGuide,
  });

  final Quest quest;
  final List<Mission> missions;
  final List<Trail> trails;
  final bool hasArcGuide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressPercent = (quest.progress.clamp(0, 1) * 100).round();
    final openMissions = missions
        .where((mission) => mission.status == MissionStatus.todo)
        .toList(growable: false);
    final completedMissions = missions
        .where((mission) => mission.status == MissionStatus.completed)
        .length;
    final latestTrail = trails.isEmpty
        ? null
        : (trails.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
            .first;
    final nextAction = _nextActionLabel(openMissions, hasArcGuide, trails);
    final theme = const QuestThemeResolver().resolve(quest);

    return QuestraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ArcWidget(
                emotion: ArcEmotion.support,
                size: 72,
                showSpeechBubble: false,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '旅路の概要 / ${theme.dnaLabel}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      nextAction,
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
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _OverviewMetric(
                icon: Icons.trending_up,
                label: '進捗',
                value: '$progressPercent%',
              ),
              _OverviewMetric(
                icon: Icons.task_alt_outlined,
                label: 'Mission',
                value: '$completedMissions/${missions.length}',
              ),
              _OverviewMetric(
                icon: Icons.timeline_outlined,
                label: 'Trail',
                value: trails.length.toString(),
              ),
              _OverviewMetric(
                icon: Icons.auto_awesome_outlined,
                label: 'Theme',
                value: theme.name,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _NextStepPanel(
            openMission: openMissions.firstOrNull,
            latestTrail: latestTrail,
            hasArcGuide: hasArcGuide,
            onOpenMission: () => context.go(AppRoutes.mission),
            onOpenTrail: () => context.go(AppRoutes.trail),
            onGenerateGuide: () => ref
                .read(arcQuestGuideControllerProvider.notifier)
                .generateForQuest(quest),
          ),
        ],
      ),
    );
  }

  String _nextActionLabel(
    List<Mission> openMissions,
    bool hasArcGuide,
    List<Trail> trails,
  ) {
    if (openMissions.isNotEmpty) {
      return '次は「${openMissions.first.title}」を進めると、このQuestが動き出します。';
    }
    if (!hasArcGuide) {
      return 'Arcガイドを生成すると、Missionと進め方が見つけやすくなります。';
    }
    if (trails.isEmpty) {
      return '最初のTrailを残すと、このQuestの航跡が見返せるようになります。';
    }
    return '進捗、Mission、Trailが揃っています。次の小さな一歩を選びましょう。';
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: QuestraColors.cosmicBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: QuestraColors.cosmicBlue.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: QuestraColors.cosmicBlue, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: QuestraColors.deepNavy,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: QuestraColors.slate,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestDnaSnapshotSection extends StatelessWidget {
  const _QuestDnaSnapshotSection({required this.quest});

  final Quest quest;

  @override
  Widget build(BuildContext context) {
    final snapshot = const QuestDnaSnapshotResolver().resolve(quest);

    return QuestraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quest DNA Snapshot',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: QuestraColors.deepNavy,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            '入力済みの情報と、Arcが航路整理のために推定した文脈です。',
            style: TextStyle(
              color: QuestraColors.slate,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final attribute in snapshot.attributes)
                _DnaAttributeChip(attribute: attribute),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showDnaReviewSheet(context, snapshot),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Quest DNAを見直す'),
              ),
              TextButton.icon(
                onPressed: () =>
                    context.go('${AppRoutes.quest}/${quest.id}/edit'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('入力情報を編集'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDnaReviewSheet(BuildContext context, QuestDnaSnapshot snapshot) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quest DNAの見直し',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  '入力はQuest編集から変更できます。推定は保存せず、入力情報から毎回再計算します。',
                  style: TextStyle(
                    color: QuestraColors.slate,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final attribute in snapshot.attributes)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              attribute.source == QuestDnaSource.userInput
                                  ? Icons.edit_note_outlined
                                  : Icons.auto_awesome_outlined,
                              color:
                                  attribute.source == QuestDnaSource.userInput
                                      ? QuestraColors.gold
                                      : QuestraColors.cosmicBlue,
                            ),
                            title: Text(attribute.label),
                            subtitle: Text(
                              attribute.source == QuestDnaSource.userInput
                                  ? '入力値'
                                  : '推定値・未保存',
                            ),
                            trailing: Text(
                              attribute.value,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.go('${AppRoutes.quest}/${quest.id}/edit');
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Quest編集で修正する'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DnaAttributeChip extends StatelessWidget {
  const _DnaAttributeChip({required this.attribute});

  final QuestDnaAttribute attribute;

  @override
  Widget build(BuildContext context) {
    final isUserInput = attribute.source == QuestDnaSource.userInput;

    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUserInput
            ? QuestraColors.gold.withValues(alpha: 0.14)
            : QuestraColors.cosmicBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUserInput
              ? QuestraColors.gold.withValues(alpha: 0.36)
              : QuestraColors.cosmicBlue.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            attribute.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: QuestraColors.slate,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            attribute.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: QuestraColors.deepNavy,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            isUserInput ? '入力' : '推定',
            style: TextStyle(
              color:
                  isUserInput ? QuestraColors.gold : QuestraColors.cosmicBlue,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengeGraphPreviewSection extends StatelessWidget {
  const _ChallengeGraphPreviewSection({
    required this.quest,
    required this.missions,
    required this.trails,
  });

  final Quest quest;
  final List<Mission> missions;
  final List<Trail> trails;

  @override
  Widget build(BuildContext context) {
    final preview = const ChallengeGraphPreviewService().buildForQuest(
      quest: quest,
      missions: missions,
      trails: trails,
    );
    final insights = const ChallengeGraphPreviewService().insightsForQuest(
      quest: quest,
      missions: missions,
      trails: trails,
    );

    return QuestraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Challenge Graph Preview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: QuestraColors.deepNavy,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Quest、Mission、Trail、Theme、Interestをつないだ将来の星図プレビューです。',
            style: TextStyle(
              color: QuestraColors.slate,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          _GraphConstellationPreview(preview: preview),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _GraphMetric(
                label: 'Nodes',
                value: preview.nodes.length.toString(),
                icon: Icons.hub_outlined,
              ),
              _GraphMetric(
                label: 'Edges',
                value: preview.edges.length.toString(),
                icon: Icons.schema_outlined,
              ),
              _GraphMetric(
                label: 'Mission',
                value: preview
                    .countNodes(ChallengeGraphNodeType.mission)
                    .toString(),
                icon: Icons.task_alt_outlined,
              ),
              _GraphMetric(
                label: 'Trail',
                value:
                    preview.countNodes(ChallengeGraphNodeType.trail).toString(),
                icon: Icons.timeline_outlined,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Arc Graph Insight',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: QuestraColors.deepNavy,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          ...insights.map(
            (insight) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _GraphInsightTile(insight: insight),
            ),
          ),
        ],
      ),
    );
  }
}

class _GraphConstellationPreview extends StatelessWidget {
  const _GraphConstellationPreview({required this.preview});

  final ChallengeGraphPreview preview;

  @override
  Widget build(BuildContext context) {
    final quest = preview.nodes.firstWhere(
      (node) => node.type == ChallengeGraphNodeType.quest,
    );
    final orbitNodes = preview.nodes
        .where((node) => node.type != ChallengeGraphNodeType.quest)
        .take(6)
        .toList(growable: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            QuestraColors.deepNavy,
            QuestraColors.cosmicBlue.withValues(alpha: 0.88),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: QuestraColors.gold.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: QuestraColors.cosmicBlue.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
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
                  color: QuestraColors.gold.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: QuestraColors.gold.withValues(alpha: 0.42),
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: QuestraColors.gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '星図ノード',
                      style: TextStyle(
                        color: QuestraColors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      quest.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: QuestraColors.white.withValues(alpha: 0.74),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _GraphNodeChip(node: quest, isPrimary: true),
              ...orbitNodes.map((node) => _GraphNodeChip(node: node)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${preview.edges.length}件のつながりをArcが案内に使えます',
            style: TextStyle(
              color: QuestraColors.white.withValues(alpha: 0.72),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GraphNodeChip extends StatelessWidget {
  const _GraphNodeChip({required this.node, this.isPrimary = false});

  final ChallengeGraphNode node;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final color = _graphNodeColor(node.type);

    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isPrimary ? 0.24 : 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.46)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_graphNodeIcon(node.type), color: color, size: 15),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              node.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: QuestraColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GraphInsightTile extends StatelessWidget {
  const _GraphInsightTile({required this.insight});

  final ChallengeGraphInsight insight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: QuestraColors.deepNavy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: QuestraColors.gold.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: QuestraColors.gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_awesome_outlined,
              color: QuestraColors.deepNavy,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: const TextStyle(
                    color: QuestraColors.deepNavy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight.message,
                  style: const TextStyle(
                    color: QuestraColors.slate,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  insight.suggestedAction,
                  style: const TextStyle(
                    color: QuestraColors.cosmicBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GraphMetric extends StatelessWidget {
  const _GraphMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: QuestraColors.cosmicBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: QuestraColors.cosmicBlue.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: QuestraColors.cosmicBlue, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: QuestraColors.deepNavy,
                  fontWeight: FontWeight.w900,
                ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: QuestraColors.slate,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _graphNodeIcon(ChallengeGraphNodeType type) {
  return switch (type) {
    ChallengeGraphNodeType.quest => Icons.explore_outlined,
    ChallengeGraphNodeType.mission => Icons.task_alt_outlined,
    ChallengeGraphNodeType.trail => Icons.timeline_outlined,
    ChallengeGraphNodeType.theme => Icons.auto_awesome_outlined,
    ChallengeGraphNodeType.interest => Icons.interests_outlined,
  };
}

Color _graphNodeColor(ChallengeGraphNodeType type) {
  return switch (type) {
    ChallengeGraphNodeType.quest => QuestraColors.gold,
    ChallengeGraphNodeType.mission => QuestraColors.skyBlue,
    ChallengeGraphNodeType.trail => const Color(0xFF8BE28B),
    ChallengeGraphNodeType.theme => const Color(0xFFFFA85C),
    ChallengeGraphNodeType.interest => const Color(0xFFA78BFA),
  };
}

class _QuestSupportBoundarySection extends StatelessWidget {
  const _QuestSupportBoundarySection({required this.quest});

  final Quest quest;

  @override
  Widget build(BuildContext context) {
    final boundary = const QuestSupportBoundaryService().resolve(quest: quest);

    return QuestraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: QuestraColors.gold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: QuestraColors.gold.withValues(alpha: 0.34),
                  ),
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: QuestraColors.deepNavy,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quest支援の透明性',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: QuestraColors.deepNavy,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      boundary.statusLabel,
                      style: const TextStyle(
                        color: QuestraColors.cosmicBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            boundary.summary,
            style: const TextStyle(
              color: QuestraColors.slate,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: boundary.roles
                .map((role) => _QuestSupportRoleChip(role: role))
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
          _SupportChecklistBlock(
            title: '表示前に必要な透明性',
            items: boundary.transparencyChecklist,
            icon: Icons.fact_check_outlined,
          ),
          const SizedBox(height: 10),
          _SupportChecklistBlock(
            title: '守る境界',
            items: boundary.guardrails,
            icon: Icons.shield_outlined,
          ),
        ],
      ),
    );
  }
}

class _QuestSupportRoleChip extends StatelessWidget {
  const _QuestSupportRoleChip({required this.role});

  final QuestSupportRole role;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: QuestraColors.cosmicBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: QuestraColors.cosmicBlue.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            role.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: QuestraColors.deepNavy,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            role.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: QuestraColors.slate,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportChecklistBlock extends StatelessWidget {
  const _SupportChecklistBlock({
    required this.title,
    required this.items,
    required this.icon,
  });

  final String title;
  final List<String> items;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: QuestraColors.deepNavy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: QuestraColors.deepNavy.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: QuestraColors.deepNavy, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: QuestraColors.deepNavy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items
                .map(
                  (item) => Chip(
                    label: Text(item),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: QuestraColors.white.withValues(
                      alpha: 0.72,
                    ),
                    side: BorderSide(
                      color: QuestraColors.gold.withValues(alpha: 0.2),
                    ),
                    labelStyle: const TextStyle(
                      color: QuestraColors.deepNavy,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _NextStepPanel extends StatelessWidget {
  const _NextStepPanel({
    required this.openMission,
    required this.latestTrail,
    required this.hasArcGuide,
    required this.onOpenMission,
    required this.onOpenTrail,
    required this.onGenerateGuide,
  });

  final Mission? openMission;
  final Trail? latestTrail;
  final bool hasArcGuide;
  final VoidCallback onOpenMission;
  final VoidCallback onOpenTrail;
  final VoidCallback onGenerateGuide;

  @override
  Widget build(BuildContext context) {
    final title = openMission != null
        ? openMission!.title
        : hasArcGuide
            ? latestTrail?.title ?? 'Trailを残す'
            : 'Arcガイドを生成';
    final message = openMission != null
        ? openMission!.description
        : hasArcGuide
            ? latestTrail?.summary ?? '今日の進み方を短く残して、次のMissionにつなげましょう。'
            : 'Questの要約、進め方、最初のMission候補をArcがまとめます。';
    final actionLabel = openMission != null
        ? 'Missionへ'
        : hasArcGuide
            ? 'Trailへ'
            : 'Arcガイドを生成';
    final actionIcon = openMission != null
        ? Icons.task_alt_outlined
        : hasArcGuide
            ? Icons.timeline_outlined
            : Icons.auto_awesome_outlined;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: QuestraColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: QuestraColors.gold.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '次の一歩',
            style: TextStyle(
              color: QuestraColors.deepNavy,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: QuestraColors.deepNavy,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(message, style: const TextStyle(color: QuestraColors.slate)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: openMission != null
                    ? onOpenMission
                    : hasArcGuide
                        ? onOpenTrail
                        : onGenerateGuide,
                icon: Icon(actionIcon),
                label: Text(actionLabel),
              ),
              if (openMission != null || hasArcGuide)
                OutlinedButton.icon(
                  onPressed: onOpenTrail,
                  icon: const Icon(Icons.timeline_outlined),
                  label: const Text('Trailを残す'),
                ),
              if (hasArcGuide)
                OutlinedButton.icon(
                  onPressed: onGenerateGuide,
                  icon: const Icon(Icons.refresh_outlined),
                  label: const Text('Guideを更新'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.quest, required this.missions});

  final Quest quest;
  final List<Mission> missions;

  @override
  Widget build(BuildContext context) {
    final progress = const QuestProgressService().calculate(missions);

    return _SectionCard(
      number: 1,
      title: '進捗',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.value,
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
                '${progress.percent}%',
                style: const TextStyle(
                  color: QuestraColors.deepNavy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '完了したMission ${progress.missionCountLabel}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text('小さなMissionを進めるほど、Questの輪郭がはっきりします。'),
          if (progress.value >= 0.85 && quest.status == QuestStatus.active) ...[
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
    final nextStatus =
        ref.read(questMilestoneServiceProvider).nextStatus(milestone.status);

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

class _ArcQuestGuidePanel extends ConsumerStatefulWidget {
  const _ArcQuestGuidePanel({required this.quest, required this.state});

  final Quest quest;
  final ArcQuestGuideState state;

  @override
  ConsumerState<_ArcQuestGuidePanel> createState() =>
      _ArcQuestGuidePanelState();
}

class _ArcQuestGuidePanelState extends ConsumerState<_ArcQuestGuidePanel> {
  ArcQuestGuide? _loadedGuide;
  MissionPlanDraft? _draft;

  void _syncGuide(ArcQuestGuide? guide) {
    if (guide != null && !identical(guide, _loadedGuide)) {
      _loadedGuide = guide;
      _draft = MissionPlanDraft.fromArcGuide(
        guide,
        questTitle: widget.quest.title,
      );
    }
  }

  void _confirmPlan() {
    final draft = _draft;
    if (draft == null || draft.validCandidates.isEmpty) return;
    final existingCount = ref
        .read(missionControllerProvider)
        .where((mission) => mission.questId == widget.quest.id)
        .length;
    final missionIds = {
      for (final candidate in draft.validCandidates)
        candidate.planKey: _missionPlanUuid.v4(),
    };
    for (var index = 0; index < draft.validCandidates.length; index++) {
      final candidate = draft.validCandidates[index];
      ref.read(missionControllerProvider.notifier).addMissionDraft(
            quest: widget.quest,
            id: missionIds[candidate.planKey],
            title: candidate.title.trim(),
            description: candidate.description.trim(),
            guideType: candidate.guideType,
            difficulty: candidate.difficulty,
            sortOrder: existingCount + index,
            isToday: candidate.isToday,
            effortEstimate: candidate.effortEstimate,
            parentMissionId: missionIds[candidate.parentPlanKey],
            dependencyIds: candidate.dependencyPlanKeys
                .map((key) => missionIds[key])
                .whereType<String>()
                .toList(growable: false),
            priority: candidate.priority,
            category: candidate.category,
            estimatedCostLabel: candidate.estimatedCostLabel,
            referenceHints: candidate.referenceHints,
            enterpriseSupportHints: candidate.enterpriseSupportHints,
            difficultyScore: candidate.difficultyScore,
            estimatedDurationDays: candidate.estimatedDurationDays,
          );
    }
    final guide = _loadedGuide;
    if (guide != null) {
      if (guide.questEvaluation != null) {
        ref
            .read(questControllerProvider.notifier)
            .update(widget.quest.copyWith(evaluation: guide.questEvaluation));
      }
      final unchanged = <int>{};
      for (var index = 0;
          index < draft.validCandidates.length &&
              index < guide.missionCandidates.length;
          index++) {
        final candidate = draft.validCandidates[index];
        final original = guide.missionCandidates[index];
        if (candidate.title.trim() == original.title.trim() &&
            candidate.description.trim() == original.description.trim()) {
          unchanged.add(index);
        }
      }
      unawaited(
        ref.read(questPlanningFeedbackRepositoryProvider).save(
              QuestPlanningFeedback(
                questId: widget.quest.id,
                categoryKey: widget.quest.category.trim().toLowerCase(),
                sourceType: guide.sourceType,
                generatedCount: guide.missionCandidates.length,
                acceptedCount: draft.validCandidates.length,
                editedCount: draft.validCandidates.length - unchanged.length,
                targetWindow: questTargetWindow(
                  widget.quest.targetDate,
                  DateTime.now(),
                ),
              ),
            ),
      );
    }
    showArcCelebrationSnackBar(
      context,
      ref.read(arcCelebrationServiceProvider).build(
            event: ArcCelebrationEvent.missionStarted,
            subject: widget.quest.title,
          ),
    );
    setState(() => _draft = null);
  }

  @override
  Widget build(BuildContext context) {
    final guide = widget.state.guideFor(widget.quest.id);
    final isLoading = widget.state.isLoading(widget.quest.id);
    final error = widget.state.errorFor(widget.quest.id);
    _syncGuide(guide);
    final draft = _draft;

    return _SectionCard(
      number: 2,
      title: 'ArcのMissionプラン',
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
                  .generateForQuest(widget.quest),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Arcガイドを生成'),
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
            if (draft == null) ...[
              const Text('Missionを保存しました。必要になったら、別の航路も描き直せます。'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => ref
                    .read(arcQuestGuideControllerProvider.notifier)
                    .generateForQuest(widget.quest),
                icon: const Icon(Icons.refresh_outlined),
                label: const Text('Mission候補を描き直す'),
              ),
            ] else ...[
              Text(
                'Mission候補を確認する',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text('編集・並べ替えをしても、確定するまでは保存されません。'),
              const SizedBox(height: 10),
              ...List.generate(draft.candidates.length, (index) {
                final candidate = draft.candidates[index];
                return Padding(
                  key: ValueKey(candidate.id),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MissionCandidateEditor(
                    index: index,
                    total: draft.candidates.length,
                    candidate: candidate,
                    onChanged: (updated) =>
                        setState(() => _draft = _draft?.update(updated)),
                    onMoveUp: index == 0
                        ? null
                        : () => setState(
                              () => _draft = _draft?.move(index, index - 1),
                            ),
                    onMoveDown: index == draft.candidates.length - 1
                        ? null
                        : () => setState(
                              () => _draft = _draft?.move(index, index + 1),
                            ),
                    onRemove: draft.candidates.length <= 1
                        ? null
                        : () => setState(
                              () => _draft = _draft?.remove(candidate.id),
                            ),
                    onToday: () => setState(
                      () => _draft = _draft?.markToday(candidate.id),
                    ),
                  ),
                );
              }),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: draft.candidates.length >= 10
                        ? null
                        : () => setState(() => _draft = _draft?.add()),
                    icon: const Icon(Icons.add),
                    label: const Text('候補を追加'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => ref
                        .read(arcQuestGuideControllerProvider.notifier)
                        .generateForQuest(widget.quest),
                    icon: const Icon(Icons.refresh_outlined),
                    label: const Text('再生成'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: draft.validCandidates.isEmpty ? null : _confirmPlan,
                icon: const Icon(Icons.check_circle_outline),
                label: Text('${draft.validCandidates.length}件のMissionを確定する'),
              ),
            ],
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

class _MissionCandidateEditor extends StatelessWidget {
  const _MissionCandidateEditor({
    required this.index,
    required this.total,
    required this.candidate,
    required this.onChanged,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
    required this.onToday,
  });

  final int index;
  final int total;
  final MissionCandidateDraft candidate;
  final ValueChanged<MissionCandidateDraft> onChanged;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onRemove;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
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
          QuestraFieldLabel(
            label: 'Mission ${index + 1} / $total',
            required: true,
            child: TextFormField(
              initialValue: candidate.title,
              decoration: const InputDecoration(),
              onChanged: (value) => onChanged(candidate.copyWith(title: value)),
              maxLength: InputLimits.missionTitle,
            ),
          ),
          const SizedBox(height: 8),
          QuestraFieldLabel(
            label: '完了が分かる具体的な一歩',
            child: TextFormField(
              initialValue: candidate.description,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(),
              onChanged: (value) =>
                  onChanged(candidate.copyWith(description: value)),
              maxLength: InputLimits.missionDescription,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _ActionChip(label: candidate.guideType.japaneseLabel),
              _ActionChip(label: candidate.difficulty.japaneseLabel),
              IconButton(
                onPressed: onToday,
                icon: Icon(
                  candidate.isToday ? Icons.today : Icons.today_outlined,
                ),
                color: candidate.isToday
                    ? QuestraColors.gold
                    : QuestraColors.slate,
                tooltip: candidate.isToday ? '今日のMission' : '今日に設定',
              ),
              IconButton(
                onPressed: onMoveUp,
                icon: const Icon(Icons.arrow_upward),
                tooltip: '上へ移動',
              ),
              IconButton(
                onPressed: onMoveDown,
                icon: const Icon(Icons.arrow_downward),
                tooltip: '下へ移動',
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: '候補を削除',
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
                ref.read(arcCelebrationServiceProvider).build(
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

class _MissionsSection extends ConsumerWidget {
  const _MissionsSection({required this.quest, required this.missions});

  final Quest quest;
  final List<Mission> missions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missionById = {for (final mission in missions) mission.id: mission};
    return _SectionCard(
      number: 3,
      title: 'このQuestのMission',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Quest「${quest.title}」を進める具体的な一歩',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (missions.isEmpty)
            const Text('Arcと最初のMissionをつくると、ここに今日の航路が並びます。')
          else
            ...List.generate(missions.length, (index) {
              final mission = missions[index];
              final parent = missionById[mission.parentMissionId];
              return Padding(
                key: ValueKey(mission.id),
                padding: EdgeInsets.only(
                  bottom: 10,
                  left: parent == null ? 0 : 18,
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: QuestraColors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: mission.status == MissionStatus.completed,
                        onChanged: mission.status == MissionStatus.completed
                            ? null
                            : (_) => ref
                                .read(missionControllerProvider.notifier)
                                .completeMission(mission.id),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (parent != null) ...[
                              Text(
                                '↳ ${parent.title}の下位Mission',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: QuestraColors.slate,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                            ],
                            Text(
                              mission.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                decoration:
                                    mission.status == MissionStatus.completed
                                        ? TextDecoration.lineThrough
                                        : null,
                              ),
                            ),
                            if (mission.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                mission.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      value: mission.progressPercent / 100,
                                      minHeight: 7,
                                      backgroundColor: QuestraColors.cloud,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                        QuestraColors.gold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${mission.progressPercent}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _ActionChip(
                                  label: mission.guideType.japaneseLabel,
                                ),
                                if (mission.isToday)
                                  const _ActionChip(label: '今日'),
                                _ActionChip(
                                  label: '優先度 ${mission.priority.label}',
                                ),
                                if (mission.estimatedDurationDays != null)
                                  _ActionChip(
                                    label:
                                        '目安 ${mission.estimatedDurationDays}日',
                                  ),
                                if (mission.dependencyIds.isNotEmpty)
                                  _ActionChip(
                                    label:
                                        '前提 ${mission.dependencyIds.length}件',
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          IconButton(
                            onPressed: mission.status == MissionStatus.completed
                                ? null
                                : () => ref
                                    .read(missionControllerProvider.notifier)
                                    .setToday(quest.id, mission.id),
                            icon: Icon(
                              mission.isToday
                                  ? Icons.today
                                  : Icons.today_outlined,
                            ),
                            color: mission.isToday
                                ? QuestraColors.gold
                                : QuestraColors.slate,
                            tooltip: mission.isToday ? '今日のMission' : '今日に設定',
                          ),
                          IconButton(
                            onPressed: () => context.push(
                              AppRoutes.missionSupport(quest.id, mission.id),
                            ),
                            icon: const Icon(Icons.menu_book_outlined),
                            tooltip: '達成に必要な情報を見る',
                          ),
                          IconButton(
                            onPressed: () =>
                                _showMissionEditDialog(context, ref, mission),
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Missionを編集',
                          ),
                          PopupMenuButton<int>(
                            tooltip: '進捗を更新',
                            icon: const Icon(Icons.tune_outlined),
                            onSelected: (value) => ref
                                .read(missionControllerProvider.notifier)
                                .updateProgress(mission.id, value),
                            itemBuilder: (context) => [
                              for (final value in const [0, 25, 50, 75, 100])
                                PopupMenuItem(
                                  value: value,
                                  child: Text('進捗 $value%'),
                                ),
                            ],
                          ),
                          IconButton(
                            onPressed: () =>
                                _confirmMissionDelete(context, ref, mission),
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Missionを削除',
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: index == 0
                                    ? null
                                    : () => ref
                                        .read(
                                          missionControllerProvider.notifier,
                                        )
                                        .reorderForQuest(
                                          quest.id,
                                          index,
                                          index - 1,
                                        ),
                                icon: const Icon(Icons.arrow_upward, size: 18),
                                tooltip: '上へ移動',
                              ),
                              IconButton(
                                onPressed: index == missions.length - 1
                                    ? null
                                    : () => ref
                                        .read(
                                          missionControllerProvider.notifier,
                                        )
                                        .reorderForQuest(
                                          quest.id,
                                          index,
                                          index + 1,
                                        ),
                                icon: const Icon(
                                  Icons.arrow_downward,
                                  size: 18,
                                ),
                                tooltip: '下へ移動',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _showMissionCreateDialog(
                  context,
                  ref,
                  quest,
                  missions.length,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Missionを追加'),
              ),
              OutlinedButton.icon(
                onPressed: () => ref
                    .read(arcQuestGuideControllerProvider.notifier)
                    .generateForQuest(quest),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('ArcにMissionを提案してもらう'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _showMissionCreateDialog(
  BuildContext context,
  WidgetRef ref,
  Quest quest,
  int sortOrder,
) async {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final shouldSave = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Missionを追加'),
      content: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QuestraFieldLabel(
                label: 'Missionの名前',
                required: true,
                child: TextFormField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: '例: 航空券の条件を比較する'),
                  maxLength: InputLimits.missionTitle,
                  validator: (value) {
                    final inputError = InputValidators.requiredText(
                      value,
                      fieldName: 'Mission名',
                      maxLength: InputLimits.missionTitle,
                    );
                    if (inputError != null) return inputError;
                    return const MissionContractService().validateTitle(
                      questTitle: quest.title,
                      missionTitle: value ?? '',
                      existingTitles: ref
                          .read(missionControllerProvider)
                          .where((mission) => mission.questId == quest.id)
                          .map((mission) => mission.title),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              QuestraFieldLabel(
                label: '完了が分かる具体的な一歩',
                child: TextFormField(
                  controller: descriptionController,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: '何ができたら完了かを書きます'),
                  maxLength: InputLimits.missionDescription,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(true);
            }
          },
          child: const Text('追加'),
        ),
      ],
    ),
  );
  if (shouldSave == true) {
    ref.read(missionControllerProvider.notifier).addMissionDraft(
          quest: quest,
          title: titleController.text.trim(),
          description: descriptionController.text.trim(),
          guideType: GuideType.route,
          difficulty: MissionDifficulty.easy,
          sortOrder: sortOrder,
        );
  }
  titleController.dispose();
  descriptionController.dispose();
}

Future<void> _showMissionEditDialog(
  BuildContext context,
  WidgetRef ref,
  Mission mission,
) async {
  final titleController = TextEditingController(text: mission.title);
  final descriptionController = TextEditingController(
    text: mission.description,
  );
  final formKey = GlobalKey<FormState>();
  final shouldSave = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Missionを編集'),
      content: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QuestraFieldLabel(
                label: 'Missionの名前',
                required: true,
                child: TextFormField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(),
                  maxLength: InputLimits.missionTitle,
                  validator: (value) {
                    final inputError = InputValidators.requiredText(
                      value,
                      fieldName: 'Mission名',
                      maxLength: InputLimits.missionTitle,
                    );
                    if (inputError != null) return inputError;
                    return const MissionContractService().validateTitle(
                      questTitle: mission.questTitle,
                      missionTitle: value ?? '',
                      existingTitles: ref
                          .read(missionControllerProvider)
                          .where(
                            (item) =>
                                item.questId == mission.questId &&
                                item.id != mission.id,
                          )
                          .map((item) => item.title),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              QuestraFieldLabel(
                label: '完了が分かる具体的な一歩',
                child: TextFormField(
                  controller: descriptionController,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(),
                  maxLength: InputLimits.missionDescription,
                  validator: (value) => InputValidators.optionalText(
                    value,
                    fieldName: '具体的な一歩',
                    maxLength: InputLimits.missionDescription,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(true);
            }
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
  if (shouldSave == true && titleController.text.trim().isNotEmpty) {
    ref.read(missionControllerProvider.notifier).updateMission(
          mission.copyWith(
            title: titleController.text.trim(),
            description: descriptionController.text.trim(),
          ),
        );
  }
  titleController.dispose();
  descriptionController.dispose();
}

Future<void> _confirmMissionDelete(
  BuildContext context,
  WidgetRef ref,
  Mission mission,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Missionを削除しますか？'),
      content: Text('「${mission.title}」を航路から外します。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('削除'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    ref.read(missionControllerProvider.notifier).removeMission(mission.id);
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
      'Arcの助言を確認',
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
                    backgroundColor:
                        i == 0 ? QuestraColors.gold : QuestraColors.cosmicBlue,
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
              ref.read(trailControllerProvider.notifier).addQuestTrail(
                    questId: quest.id,
                    missionId: latestMission?.id,
                    questTitle: quest.title,
                  );
              showArcCelebrationSnackBar(
                context,
                ref.read(arcCelebrationServiceProvider).build(
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

class _DreamBoardSection extends ConsumerWidget {
  const _DreamBoardSection({required this.quest, required this.starMap});

  final Quest quest;
  final List<StarMapItem> starMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(dreamBoardControllerProvider)[quest.id] ??
        const <DreamBoardItem>[];
    final controller = ref.read(dreamBoardControllerProvider.notifier);
    final firstReference = starMap.isEmpty ? null : starMap.first;

    return _SectionCard(
      number: 8,
      title: 'Dream Board',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('「${quest.title}」を叶えるための理想イメージと参考素材を集めます。'),
          const SizedBox(height: 12),
          if (items.isEmpty)
            _DreamBoardEmptyState(
              onAddVision: () => controller.addItem(
                questId: quest.id,
                title: '理想の到達点',
                note: '${quest.title}を達成した未来の景色を置いておきます。',
                itemType: DreamBoardItemType.vision,
              ),
              onAddReference: firstReference == null
                  ? null
                  : () => controller.addItem(
                        questId: quest.id,
                        title: firstReference.title,
                        note: firstReference.description,
                        itemType: DreamBoardItemType.reference,
                        sourceUrl: firstReference.url,
                        metadata: {
                          'guide_type': firstReference.guideType.name,
                          'content_type': firstReference.contentType,
                        },
                      ),
            )
          else ...[
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DreamBoardTile(
                  item: item,
                  onRemove: () => controller.removeItem(item),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => controller.addItem(
                    questId: quest.id,
                    title: '次に見たい景色',
                    note: 'このQuestで見たい景色をもう一つ追加します。',
                    itemType: DreamBoardItemType.vision,
                  ),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('理想を追加'),
                ),
                if (firstReference != null)
                  OutlinedButton.icon(
                    onPressed: () => controller.addItem(
                      questId: quest.id,
                      title: firstReference.title,
                      note: firstReference.description,
                      itemType: DreamBoardItemType.reference,
                      sourceUrl: firstReference.url,
                      metadata: {
                        'guide_type': firstReference.guideType.name,
                        'content_type': firstReference.contentType,
                      },
                    ),
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('参考星を追加'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DreamBoardEmptyState extends StatelessWidget {
  const _DreamBoardEmptyState({
    required this.onAddVision,
    required this.onAddReference,
  });

  final VoidCallback onAddVision;
  final VoidCallback? onAddReference;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
          const ArcWidget(
            emotion: ArcEmotion.support,
            size: 64,
            message: 'まだ白い星図だね。叶えたい景色をひとつ置くと、航路が少し見えやすくなるよ。',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onAddVision,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('理想を追加'),
              ),
              if (onAddReference != null)
                OutlinedButton.icon(
                  onPressed: onAddReference,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('参考星を追加'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DreamBoardTile extends StatelessWidget {
  const _DreamBoardTile({required this.item, required this.onRemove});

  final DreamBoardItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: QuestraColors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: QuestraColors.gold.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: QuestraColors.gold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _dreamBoardIcon(item.itemType),
              color: QuestraColors.midnightNavy,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: QuestraColors.midnightNavy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.note,
                  style: const TextStyle(color: QuestraColors.slate),
                ),
                const SizedBox(height: 8),
                _ActionChip(label: item.itemType.label),
              ],
            ),
          ),
          IconButton(
            tooltip: '削除',
            onPressed: onRemove,
            icon: const Icon(Icons.close),
            color: QuestraColors.slate,
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

IconData _dreamBoardIcon(DreamBoardItemType itemType) {
  return switch (itemType) {
    DreamBoardItemType.vision => Icons.landscape_outlined,
    DreamBoardItemType.reference => Icons.auto_awesome_outlined,
    DreamBoardItemType.tool => Icons.construction_outlined,
    DreamBoardItemType.guild => Icons.groups_outlined,
    DreamBoardItemType.generatedBackground => Icons.wallpaper_outlined,
  };
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
