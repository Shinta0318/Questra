import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/performance/performance_limits.dart';
import '../../core/analytics/analytics_event.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/feature_flags/trail_feature_flags.dart';
import '../../core/persistence/persistence_sync_state.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/questra_colors.dart';
import '../../core/validation/input_validators.dart';
import '../../widgets/forms/questra_field_label.dart';
import '../../widgets/forms/questra_modal_sheet.dart';
import '../../widgets/arc/arc_presence.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/layout/questra_journey_scaffold.dart';
import '../../widgets/menu/questra_action_menu.dart';
import '../../widgets/persistence_sync_banner.dart';
import '../../widgets/questra_card.dart';
import '../arc/arc_celebration_service.dart';
import '../arc/arc_guidance_providers.dart';
import '../arc/arc_reflection_coach_service.dart';
import '../auth/auth_controller.dart';
import '../media/media_model.dart';
import '../mission/mission_controller.dart';
import '../mission/mission_model.dart';
import '../quest/quest_controller.dart';
import '../quest/quest_model.dart';
import '../task/task_controller.dart';
import '../task/task_model.dart';
import 'trail_controller.dart';
import 'trail_draft_repository.dart';
import 'trail_highlight_service.dart';
import 'trail_journey_projection.dart';
import 'trail_model.dart';
import 'trail_pagination_state.dart';
import 'trail_share_policy.dart';
import 'trail_share_providers.dart';
import 'trail_share_repository.dart';
import 'trail_sync_state.dart';
import 'trail_timeline_widget.dart';

final trailHighlightServiceProvider = Provider<TrailHighlightService>((ref) {
  return const TrailHighlightService();
});

typedef TrailFilterRouteChanged =
    void Function(String? questId, String? missionId);

class TrailScreen extends ConsumerStatefulWidget {
  const TrailScreen({
    super.key,
    this.initialParent,
    this.initialFilterQuestId,
    this.initialFilterMissionId,
    this.onFilterRouteChanged,
    this.openComposer = false,
  });

  final TrailParentContext? initialParent;
  final String? initialFilterQuestId;
  final String? initialFilterMissionId;
  final TrailFilterRouteChanged? onFilterRouteChanged;
  final bool openComposer;

  @override
  ConsumerState<TrailScreen> createState() => _TrailScreenState();
}

class _TrailScreenState extends ConsumerState<TrailScreen> {
  bool _didOpenComposer = false;
  String? _filterQuestId;
  String? _filterMissionId;

  @override
  void initState() {
    super.initState();
    _applyInitialFilter();
  }

  @override
  void didUpdateWidget(covariant TrailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilterQuestId != widget.initialFilterQuestId ||
        oldWidget.initialFilterMissionId != widget.initialFilterMissionId) {
      _applyInitialFilter();
    }
  }

  void _applyInitialFilter() {
    _filterQuestId = widget.initialFilterQuestId;
    _filterMissionId = widget.initialFilterQuestId == null
        ? null
        : widget.initialFilterMissionId;
  }

  void _setJourneyFilter(String? questId, String? missionId) {
    setState(() {
      _filterQuestId = questId;
      _filterMissionId = questId == null ? null : missionId;
    });
    widget.onFilterRouteChanged?.call(
      questId,
      questId == null ? null : missionId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final trails = ref.watch(trailControllerProvider);
    final quests = ref.watch(questControllerProvider);
    final missions = ref.watch(missionControllerProvider);
    final tasks = ref.watch(taskControllerProvider);
    final trailMedia = ref.watch(trailMediaControllerProvider);
    final syncState = ref.watch(trailSyncControllerProvider);
    final paginationState = ref.watch(trailPaginationControllerProvider);
    final profile = ref.watch(authControllerProvider).profile;
    final controller = ref.read(trailControllerProvider.notifier);
    final singleTimelineEnabled =
        const TrailFeatureFlags().singleTimelineEnabled;
    final shareRepository = ref.watch(trailShareRepositoryProvider);
    final trailHighlights = ref
        .watch(trailHighlightServiceProvider)
        .rank(trails: trails, attachments: trailMedia);
    final expressionEngine = ref.watch(arcExpressionEngineProvider);
    final arcExpression = expressionEngine.resolveJourney(
      quests: const [],
      missions: const [],
      trails: trails,
    );
    final hierarchyByTrailId = <String, TrailParentContext>{};
    for (final trail in trails) {
      final parent = _parentForTrail(trail, missions, tasks);
      if (parent != null) hierarchyByTrailId[trail.id] = parent;
    }
    final filterQuestId = quests.any((quest) => quest.id == _filterQuestId)
        ? _filterQuestId
        : null;
    final filterMissionId =
        missions.any(
          (mission) =>
              mission.id == _filterMissionId &&
              mission.questId == filterQuestId,
        )
        ? _filterMissionId
        : null;
    final filterQuest = quests
        .where((quest) => quest.id == filterQuestId)
        .firstOrNull;
    final selectableFilterMissions = missions
        .where(
          (mission) =>
              mission.questId == filterQuestId &&
              mission.routeState != MissionRouteState.removed,
        )
        .toList(growable: false);
    final filterMission = selectableFilterMissions
        .where((mission) => mission.id == filterMissionId)
        .firstOrNull;
    final canCreateInFilter =
        filterQuest != null &&
        filterQuest.status != QuestStatus.archived &&
        (filterMissionId == null
            ? selectableFilterMissions.isNotEmpty
            : filterMission != null);
    final journeyProjection = projectTrailJourney(
      trails,
      questId: filterQuestId,
      missionId: filterMissionId,
    );
    final visibleTrails = journeyProjection.trails;
    final visibleTrailIds = journeyProjection.trailIds;
    final visibleTrailMedia = <String, MediaAttachment>{
      for (final entry in trailMedia.entries)
        if (visibleTrailIds.contains(entry.key)) entry.key: entry.value,
    };
    final visibleHighlights = <String, TrailHighlight>{
      for (final highlight in trailHighlights)
        if (visibleTrailIds.contains(highlight.trailId))
          highlight.trailId: highlight,
    };

    if (widget.openComposer && !_didOpenComposer) {
      _didOpenComposer = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showCreateTrailSheet(
          context,
          ref.read(trailControllerProvider.notifier),
          parent: widget.initialParent,
          initialQuestId: filterQuestId,
          initialMissionId: filterMissionId,
        );
      });
    }

    return QuestraJourneyScaffold(
      title: 'Trail',
      child: QuestraResponsiveListView(
        showScrollbar: true,
        onRefresh: profile == null
            ? null
            : () => controller.loadForUser(profile.id),
        padding: const EdgeInsets.all(20),
        children: singleTimelineEnabled
            ? [
                if (syncState.status != TrailSyncStatus.idle) ...[
                  PersistenceSyncBanner(
                    state: _toPersistenceState(syncState),
                    onRetry:
                        profile == null ||
                            syncState.operation != TrailSyncOperation.load
                        ? null
                        : () => controller.loadForUser(profile.id),
                    onDismiss: () =>
                        ref.read(trailSyncControllerProvider.notifier).clear(),
                  ),
                  const SizedBox(height: 12),
                ],
                if (trails.isNotEmpty) ...[
                  _TrailJourneyFilter(
                    quests: quests,
                    missions: missions,
                    trails: trails,
                    resultCount: visibleTrails.length,
                    selectedQuestId: filterQuestId,
                    selectedMissionId: filterMissionId,
                    onQuestChanged: (value) => _setJourneyFilter(value, null),
                    onMissionChanged: (value) =>
                        _setJourneyFilter(filterQuestId, value),
                    onClear: () => _setJourneyFilter(null, null),
                  ),
                  const SizedBox(height: 16),
                ],
                if (visibleTrails.isEmpty && trails.isNotEmpty)
                  _TrailFilterEmpty(
                    mayHaveOlderTrails: paginationState.canRequestMore,
                    loadMoreButton:
                        profile != null && paginationState.canRequestMore
                        ? _TrailLoadMoreButton(
                            state: paginationState,
                            onPressed: () =>
                                controller.loadMoreForUser(profile.id),
                          )
                        : null,
                    onClear: () => _setJourneyFilter(null, null),
                    onCreate: !canCreateInFilter
                        ? null
                        : () => _showCreateTrailSheet(
                            context,
                            controller,
                            initialQuestId: filterQuestId,
                            initialMissionId: filterMissionId,
                          ),
                  )
                else
                  TrailTimelineWidget(
                    trails: visibleTrails,
                    attachments: visibleTrailMedia,
                    highlights: visibleHighlights,
                    hierarchyByTrailId: hierarchyByTrailId,
                    onCreateTrail: () => _showCreateTrailSheet(
                      context,
                      controller,
                      parent: widget.initialParent,
                      initialQuestId: filterQuestId,
                      initialMissionId: filterMissionId,
                    ),
                    itemBuilder: (context, trail) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildTrailCard(
                        context,
                        ref,
                        controller,
                        trail,
                        missions,
                        trailMedia,
                        hierarchyByTrailId,
                        shareRepository,
                      ),
                    ),
                  ),
                if (profile != null &&
                    paginationState.canRequestMore &&
                    visibleTrails.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _TrailLoadMoreButton(
                    state: paginationState,
                    onPressed: () => controller.loadMoreForUser(profile.id),
                  ),
                ],
              ]
            : [
                ArcPresence(
                  surface: ArcPresenceSurface.trail,
                  emotion: arcExpression.emotion,
                  message: 'TrailはQuestとMissionの足あとを、あとで戻れる航路として残してくれるよ。',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const ValueKey('trail-primary-create'),
                  onPressed: () => _showCreateTrailSheet(
                    context,
                    controller,
                    parent: widget.initialParent,
                    initialQuestId: filterQuestId,
                    initialMissionId: filterMissionId,
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(trails.isEmpty ? '最初のTrailを残す' : 'Trailを残す'),
                ),
                const SizedBox(height: 16),
                if (syncState.status != TrailSyncStatus.idle) ...[
                  PersistenceSyncBanner(
                    state: _toPersistenceState(syncState),
                    onRetry:
                        profile == null ||
                            syncState.operation != TrailSyncOperation.load
                        ? null
                        : () => controller.loadForUser(profile.id),
                    onDismiss: () =>
                        ref.read(trailSyncControllerProvider.notifier).clear(),
                  ),
                  const SizedBox(height: 12),
                ],
                if (trails.isNotEmpty) ...[
                  _TrailJourneyFilter(
                    quests: quests,
                    missions: missions,
                    trails: trails,
                    resultCount: visibleTrails.length,
                    selectedQuestId: filterQuestId,
                    selectedMissionId: filterMissionId,
                    onQuestChanged: (value) => _setJourneyFilter(value, null),
                    onMissionChanged: (value) =>
                        _setJourneyFilter(filterQuestId, value),
                    onClear: () => _setJourneyFilter(null, null),
                  ),
                  const SizedBox(height: 16),
                ],
                _TrailOverview(trails: visibleTrails),
                const SizedBox(height: 16),
                if (visibleTrails.isEmpty && trails.isNotEmpty)
                  _TrailFilterEmpty(
                    mayHaveOlderTrails: paginationState.canRequestMore,
                    loadMoreButton:
                        profile != null && paginationState.canRequestMore
                        ? _TrailLoadMoreButton(
                            state: paginationState,
                            onPressed: () =>
                                controller.loadMoreForUser(profile.id),
                          )
                        : null,
                    onClear: () => _setJourneyFilter(null, null),
                    onCreate: !canCreateInFilter
                        ? null
                        : () => _showCreateTrailSheet(
                            context,
                            controller,
                            initialQuestId: filterQuestId,
                            initialMissionId: filterMissionId,
                          ),
                  )
                else
                  TrailTimelineWidget(
                    trails: visibleTrails,
                    attachments: visibleTrailMedia,
                    highlights: visibleHighlights,
                    hierarchyByTrailId: hierarchyByTrailId,
                  ),
                const SizedBox(height: 16),
                ...visibleTrails.map(
                  (trail) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildTrailCard(
                      context,
                      ref,
                      controller,
                      trail,
                      missions,
                      trailMedia,
                      hierarchyByTrailId,
                      shareRepository,
                    ),
                  ),
                ),
                if (profile != null &&
                    paginationState.canRequestMore &&
                    visibleTrails.isNotEmpty)
                  _TrailLoadMoreButton(
                    state: paginationState,
                    onPressed: () => controller.loadMoreForUser(profile.id),
                  ),
              ],
      ),
    );
  }

  Widget _buildTrailCard(
    BuildContext context,
    WidgetRef ref,
    TrailController controller,
    Trail trail,
    List<Mission> missions,
    Map<String, MediaAttachment> trailMedia,
    Map<String, TrailParentContext> hierarchyByTrailId,
    TrailShareRepository? shareRepository,
  ) {
    final parent = hierarchyByTrailId[trail.id];
    return _TrailCard(
      trail: trail,
      parent: parent,
      attachment: trailMedia[trail.id],
      onOpenQuest: parent == null
          ? null
          : () => context.push('${AppRoutes.quest}/${parent.questId}'),
      onOpenMission: parent?.missionId == null
          ? null
          : () => context.push(
              AppRoutes.missionDetail(parent!.questId, parent.missionId!),
            ),
      onEdit: () => _showEditTrailSheet(context, controller, trail),
      onReflect: () => _showReflectTrailSheet(
        context,
        ref,
        controller,
        trail,
        _missionForTrail(trail, missions),
      ),
      onAttachImage: () => _attachTrailImage(context, controller, trail),
      onReplaceImage: trailMedia[trail.id] == null
          ? null
          : () => _replaceTrailImage(
              context,
              controller,
              trail,
              trailMedia[trail.id]!,
            ),
      onRemoveImage: trailMedia[trail.id] == null
          ? null
          : () => _confirmRemoveTrailImage(
              context,
              controller,
              trail,
              trailMedia[trail.id]!,
            ),
      onShare: shareRepository == null
          ? null
          : () => _shareTrail(context, shareRepository, trail),
      onDelete: () => _confirmDeleteTrail(context, controller, trail),
    );
  }

  Mission? _missionForTrail(Trail trail, List<Mission> missions) {
    final missionId = trail.missionId;
    if (missionId == null) {
      return null;
    }
    return missions.where((mission) => mission.id == missionId).firstOrNull;
  }

  TrailParentContext? _parentForTrail(
    Trail trail,
    List<Mission> missions,
    List<QuestraTask> tasks,
  ) {
    if (trail.taskId case final taskId?) {
      final task = tasks.where((item) => item.id == taskId).firstOrNull;
      if (task != null &&
          task.questId == trail.questId &&
          task.missionId == trail.missionId) {
        return TrailParentContext(
          questId: task.questId,
          questTitle: task.questTitle,
          missionId: task.missionId,
          missionTitle: task.missionTitle,
          taskId: task.id,
          taskTitle: task.title,
        );
      }
    }
    if (trail.missionId case final missionId?) {
      final mission = missions
          .where(
            (item) => item.id == missionId && item.questId == trail.questId,
          )
          .firstOrNull;
      if (mission != null) {
        return TrailParentContext(
          questId: mission.questId,
          questTitle: mission.questTitle,
          missionId: mission.id,
          missionTitle: mission.title,
        );
      }
    }
    if (widget.initialParent case final initialParent?) {
      if (initialParent.questId == trail.questId &&
          (trail.missionId == null ||
              initialParent.missionId == trail.missionId) &&
          (trail.taskId == null || initialParent.taskId == trail.taskId)) {
        return initialParent;
      }
    }
    return null;
  }

  Future<void> _replaceTrailImage(
    BuildContext context,
    TrailController controller,
    Trail trail,
    MediaAttachment current,
  ) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: QuestraPerformanceLimits.trailImageMaxWidth,
      maxHeight: QuestraPerformanceLimits.trailImageMaxHeight,
      imageQuality: QuestraPerformanceLimits.trailImageQuality,
    );
    if (image == null) {
      return;
    }

    final attachment = await controller.replaceImageForTrail(
      trail: trail,
      current: current,
      image: image,
    );
    if (context.mounted && attachment != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Trail画像を置き換えました。')));
    }
  }

  Future<void> _confirmRemoveTrailImage(
    BuildContext context,
    TrailController controller,
    Trail trail,
    MediaAttachment attachment,
  ) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('画像を削除しますか？'),
        content: Text('「${trail.title}」に添付された画像を削除します。'),
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

    if (shouldRemove == true) {
      final removed = await controller.removeImageFromTrail(
        trail: trail,
        attachment: attachment,
      );
      if (context.mounted && removed) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Trail画像を削除しました。')));
      }
    }
  }

  Future<void> _showCreateTrailSheet(
    BuildContext context,
    TrailController controller, {
    TrailParentContext? parent,
    String? initialQuestId,
    String? initialMissionId,
  }) async {
    final ownerId = ref.read(authControllerProvider).profile?.id;
    var handedOffToQuest = false;
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .trailJourney(
            name: AnalyticsEventName.trailComposerOpened,
            surface: parent != null
                ? 'task_parent'
                : widget.openComposer
                ? 'route'
                : 'trail',
            outcome: 'opened',
            hasQuest: parent?.questId != null || initialQuestId != null,
            hasMission: parent?.missionId != null || initialMissionId != null,
          ),
    );
    TrailComposerDraft? restoredDraft;
    if (ownerId != null) {
      try {
        restoredDraft = await ref
            .read(trailDraftRepositoryProvider)
            .load(ownerId);
      } catch (_) {
        // Draft recovery is best effort and must not block Trail creation.
      }
    }
    if (!context.mounted) return;
    final saved = await showQuestraModalSheet<bool>(
      context: context,
      builder: (_) => _CreateTrailSheet(
        parent: parent,
        initialQuestId: initialQuestId,
        initialMissionId: initialMissionId,
        draftOwnerId: ownerId,
        restoredDraft: restoredDraft,
        onOpenQuest: (questId) {
          handedOffToQuest = true;
          unawaited(
            ref
                .read(analyticsServiceProvider)
                .trailJourney(
                  name: AnalyticsEventName.trailMissionRecoveryOpened,
                  surface: 'trail_composer',
                  outcome: 'mission_missing',
                  hasQuest: true,
                  hasMission: false,
                ),
          );
          context.go(AppRoutes.questDetailForTrailMission(questId));
        },
        onSubmit: (draft) => controller.addManualTrailAndWait(
          trailId: draft.id,
          title: draft.title,
          summary: draft.summary,
          content: draft.content,
          parent: parent ?? draft.parent,
        ),
      ),
    );
    if (saved == true) {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .trailJourney(
              name: AnalyticsEventName.trailComposerCompleted,
              surface: widget.openComposer ? 'route' : 'trail',
              outcome: 'saved',
              hasQuest: true,
              hasMission: true,
            ),
      );
    }
    if (!mounted || handedOffToQuest || !widget.openComposer) return;
    widget.onFilterRouteChanged?.call(_filterQuestId, _filterMissionId);
  }

  void _showEditTrailSheet(
    BuildContext context,
    TrailController controller,
    Trail trail,
  ) {
    showQuestraModalSheet<void>(
      context: context,
      builder: (context) => _EditTrailSheet(
        trail: trail,
        onSubmit: controller.updateTrailWithResult,
      ),
    );
  }

  void _showReflectTrailSheet(
    BuildContext context,
    WidgetRef ref,
    TrailController controller,
    Trail trail,
    Mission? mission,
  ) {
    final coach = ref
        .read(arcReflectionCoachServiceProvider)
        .build(trail: trail, mission: mission);
    showQuestraModalSheet<void>(
      context: context,
      builder: (context) => _ReflectTrailSheet(
        trail: trail,
        mission: mission,
        coach: coach,
        onSubmit: (updatedTrail) async {
          final saved = await controller.updateTrailAndWait(updatedTrail);
          if (!saved || !context.mounted) return saved;
          showArcCelebrationSnackBar(
            context,
            ref
                .read(arcCelebrationServiceProvider)
                .build(
                  event: ArcCelebrationEvent.trailReflection,
                  subject: updatedTrail.title,
                ),
          );
          return true;
        },
      ),
    );
  }

  Future<void> _attachTrailImage(
    BuildContext context,
    TrailController controller,
    Trail trail,
  ) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: QuestraPerformanceLimits.trailImageMaxWidth,
      maxHeight: QuestraPerformanceLimits.trailImageMaxHeight,
      imageQuality: QuestraPerformanceLimits.trailImageQuality,
    );
    if (image == null) {
      return;
    }

    final attachment = await controller.attachImageToTrail(
      trail: trail,
      image: image,
    );
    if (context.mounted && attachment != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Trailに画像を添付しました。')));
    }
  }

  Future<void> _confirmDeleteTrail(
    BuildContext context,
    TrailController controller,
    Trail trail,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trailを削除しますか？'),
        content: Text('「${trail.title}」をTrailから削除します。'),
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

    if (shouldDelete == true) {
      await controller.removeTrailAndWait(trail.id);
    }
  }

  Future<void> _shareTrail(
    BuildContext context,
    TrailShareRepository repository,
    Trail trail,
  ) async {
    var includeTitle = true;
    var includeSummary = true;
    var includeContent = false;
    var lifetimeDays = 7;
    final selection = await showDialog<_TrailShareSelection>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Trailを共有'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('共有する内容だけを選んでください。画像、プロフィール、Questへのリンクは含まれません。'),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: includeTitle,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Trailの名前'),
                  onChanged: (value) => setDialogState(
                    () => includeTitle = value ?? includeTitle,
                  ),
                ),
                CheckboxListTile(
                  value: includeSummary,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ひとことの振り返り'),
                  onChanged: (value) => setDialogState(
                    () => includeSummary = value ?? includeSummary,
                  ),
                ),
                CheckboxListTile(
                  value: includeContent,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('詳しい記録'),
                  onChanged: (value) => setDialogState(
                    () => includeContent = value ?? includeContent,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: lifetimeDays,
                  decoration: const InputDecoration(labelText: '共有期限'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1日')),
                    DropdownMenuItem(value: 7, child: Text('7日')),
                    DropdownMenuItem(value: 30, child: Text('30日')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => lifetimeDays = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: includeTitle || includeSummary || includeContent
                  ? () => Navigator.pop(
                      context,
                      _TrailShareSelection(
                        includeTitle: includeTitle,
                        includeSummary: includeSummary,
                        includeContent: includeContent,
                        lifetimeDays: lifetimeDays,
                      ),
                    )
                  : null,
              child: const Text('リンクを作成'),
            ),
          ],
        ),
      ),
    );
    if (selection == null || !context.mounted) return;
    final expiresAt = DateTime.now().add(
      Duration(days: selection.lifetimeDays),
    );
    final fields = <TrailShareField>{
      if (selection.includeTitle) TrailShareField.title,
      if (selection.includeSummary) TrailShareField.summary,
      if (selection.includeContent) TrailShareField.content,
    };
    final review = const TrailSharePolicy().review(
      TrailShareDraft(trail: trail, fields: fields, expiresAt: expiresAt),
    );
    if (!review.isSafe) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(review.reason ?? '共有内容を確認してください。')),
      );
      return;
    }
    try {
      final link = await repository.create(
        trailId: trail.id,
        includeTitle: selection.includeTitle,
        includeSummary: selection.includeSummary,
        includeContent: selection.includeContent,
        expiresAt: expiresAt,
      );
      final origin = kIsWeb ? Uri.base.origin : 'https://app.questra.jp';
      final url = '$origin/#${AppRoutes.trailShareLink(link.token)}';
      await Clipboard.setData(ClipboardData(text: url));
      if (!context.mounted) return;
      final revoke = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('共有リンクをコピーしました'),
          content: Text(
            '${link.expiresAt.year}/${link.expiresAt.month.toString().padLeft(2, '0')}/${link.expiresAt.day.toString().padLeft(2, '0')}まで有効です。受信者はQuestraへのログインが必要です。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('共有を取り消す'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
      if (revoke == true) {
        await repository.revoke(link.id);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('共有を取り消しました。')));
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('共有リンクを作成できませんでした。内容を確認してください。')),
        );
      }
    }
  }
}

class _TrailShareSelection {
  const _TrailShareSelection({
    required this.includeTitle,
    required this.includeSummary,
    required this.includeContent,
    required this.lifetimeDays,
  });

  final bool includeTitle;
  final bool includeSummary;
  final bool includeContent;
  final int lifetimeDays;
}

class _TrailJourneyFilter extends StatelessWidget {
  const _TrailJourneyFilter({
    required this.quests,
    required this.missions,
    required this.trails,
    required this.resultCount,
    required this.selectedQuestId,
    required this.selectedMissionId,
    required this.onQuestChanged,
    required this.onMissionChanged,
    required this.onClear,
  });

  final List<Quest> quests;
  final List<Mission> missions;
  final List<Trail> trails;
  final int resultCount;
  final String? selectedQuestId;
  final String? selectedMissionId;
  final ValueChanged<String?> onQuestChanged;
  final ValueChanged<String?> onMissionChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final questIds = trails
        .map((trail) => trail.questId)
        .whereType<String>()
        .toSet();
    final filterQuests = quests
        .where(
          (quest) => questIds.contains(quest.id) || quest.id == selectedQuestId,
        )
        .toList(growable: false);
    final missionIds = trails
        .where((trail) => trail.questId == selectedQuestId)
        .map((trail) => trail.missionId)
        .whereType<String>()
        .toSet();
    final filterMissions = missions
        .where(
          (mission) =>
              mission.questId == selectedQuestId &&
              (missionIds.contains(mission.id) ||
                  mission.id == selectedMissionId),
        )
        .toList(growable: false);
    final hasFilter = selectedQuestId != null || selectedMissionId != null;

    Widget questField() => QuestraFieldLabel(
      label: 'Quest',
      child: Semantics(
        container: true,
        label: '表示するQuestを選択',
        child: DropdownButtonFormField<String?>(
          key: const ValueKey('trail-filter-quest'),
          initialValue: selectedQuestId,
          isExpanded: true,
          decoration: const InputDecoration(
            hintText: 'すべてのQuest',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('すべてのQuest'),
            ),
            for (final quest in filterQuests)
              DropdownMenuItem<String?>(
                value: quest.id,
                child: Text(
                  quest.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onQuestChanged,
        ),
      ),
    );
    Widget missionField() => QuestraFieldLabel(
      label: 'Mission',
      child: Semantics(
        container: true,
        label: selectedQuestId == null ? '先に表示するQuestを選択' : '表示するMissionを選択',
        child: DropdownButtonFormField<String?>(
          key: ValueKey('trail-filter-mission-${selectedQuestId ?? 'all'}'),
          initialValue: selectedMissionId,
          isExpanded: true,
          decoration: const InputDecoration(
            hintText: 'すべてのMission',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('すべてのMission'),
            ),
            for (final mission in filterMissions)
              DropdownMenuItem<String?>(
                value: mission.id,
                child: Text(
                  mission.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: selectedQuestId == null ? null : onMissionChanged,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '表示する航路',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (hasFilter)
              IconButton(
                key: const ValueKey('trail-filter-clear'),
                onPressed: onClear,
                tooltip: '絞り込みを解除',
                icon: const Icon(Icons.filter_alt_off_outlined),
              ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 560) {
              return Column(
                children: [
                  questField(),
                  const SizedBox(height: 10),
                  missionField(),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: questField()),
                const SizedBox(width: 12),
                Expanded(child: missionField()),
              ],
            );
          },
        ),
        if (hasFilter) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            label: '絞り込み結果、Trailを$resultCount件表示しています',
            child: ExcludeSemantics(
              child: Text(
                '$resultCount件のTrailを表示',
                key: const ValueKey('trail-filter-result-count'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TrailFilterEmpty extends StatelessWidget {
  const _TrailFilterEmpty({
    required this.mayHaveOlderTrails,
    required this.onClear,
    this.loadMoreButton,
    this.onCreate,
  });

  final bool mayHaveOlderTrails;
  final VoidCallback onClear;
  final Widget? loadMoreButton;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.route_outlined, size: 36),
          const SizedBox(height: 8),
          Text(
            mayHaveOlderTrails
                ? '読み込んだ範囲には、この航路のTrailがありません。'
                : 'この航路にはまだTrailがありません。',
            textAlign: TextAlign.center,
          ),
          if (mayHaveOlderTrails) ...[
            const SizedBox(height: 4),
            Text(
              '過去のTrailを読み込むと見つかる可能性があります。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (loadMoreButton case final button?) ...[
            const SizedBox(height: 8),
            button,
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (onCreate != null)
                FilledButton.icon(
                  key: const ValueKey('trail-filter-empty-create'),
                  onPressed: onCreate,
                  icon: const Icon(Icons.add),
                  label: const Text('この航路にTrailを残す'),
                ),
              TextButton(onPressed: onClear, child: const Text('すべてのTrailを見る')),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrailLoadMoreButton extends StatelessWidget {
  const _TrailLoadMoreButton({required this.state, required this.onPressed});

  final TrailPaginationState state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (state.errorMessage case final message?) ...[
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          key: const ValueKey('trail-load-more'),
          onPressed: state.isLoading ? null : onPressed,
          icon: state.isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.expand_more),
          label: Text(state.isLoading ? '読み込んでいます...' : '過去のTrailをさらに表示'),
        ),
      ],
    );
  }
}

class _TrailDraft {
  const _TrailDraft({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.parent,
  });

  final String id;
  final String title;
  final String summary;
  final String content;
  final TrailParentContext? parent;
}

class _CreateTrailSheet extends ConsumerStatefulWidget {
  const _CreateTrailSheet({
    required this.onSubmit,
    this.parent,
    this.initialQuestId,
    this.initialMissionId,
    this.draftOwnerId,
    this.restoredDraft,
    this.onOpenQuest,
  });

  final Future<bool> Function(_TrailDraft) onSubmit;
  final TrailParentContext? parent;
  final String? initialQuestId;
  final String? initialMissionId;
  final String? draftOwnerId;
  final TrailComposerDraft? restoredDraft;
  final ValueChanged<String>? onOpenQuest;

  @override
  ConsumerState<_CreateTrailSheet> createState() => _CreateTrailSheetState();
}

enum _TrailDraftSaveStatus { idle, saving, saved, failed }

class _CreateTrailSheetState extends ConsumerState<_CreateTrailSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _draftId;
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _contentController = TextEditingController();
  Timer? _draftSaveTimer;
  Future<void> _pendingDraftWrite = Future.value();
  bool _isSaving = false;
  bool _showDetails = false;
  bool _draftRestored = false;
  TrailComposerDraft? _conflictingDraft;
  _TrailDraftSaveStatus _draftSaveStatus = _TrailDraftSaveStatus.idle;
  int _draftWriteVersion = 0;
  String? _errorMessage;
  String? _selectedQuestId;
  String? _selectedMissionId;

  @override
  void initState() {
    super.initState();
    _draftId = Trail.createId();
    if (widget.parent == null) {
      _selectedQuestId = widget.initialQuestId;
      _selectedMissionId = widget.initialQuestId == null
          ? null
          : widget.initialMissionId;
    }
    _applyRestoredDraft(widget.restoredDraft);
    _titleController.addListener(_scheduleDraftSave);
    _summaryController.addListener(_scheduleDraftSave);
    _contentController.addListener(_scheduleDraftSave);
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    _titleController.dispose();
    _summaryController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectableQuests =
        ref
            .watch(questControllerProvider)
            .where((quest) => quest.status != QuestStatus.archived)
            .toList(growable: false)
          ..sort(_compareTrailQuestChoice);
    final selectedQuest = selectableQuests
        .where((quest) => quest.id == _selectedQuestId)
        .firstOrNull;
    final selectableMissions =
        ref
            .watch(missionControllerProvider)
            .where(
              (mission) =>
                  mission.questId == selectedQuest?.id &&
                  mission.routeState != MissionRouteState.removed,
            )
            .toList(growable: false)
          ..sort(_compareTrailMissionChoice);
    final selectedMission = selectableMissions
        .where((mission) => mission.id == _selectedMissionId)
        .firstOrNull;
    final unavailableParentMessage =
        _selectedQuestId != null && selectedQuest == null
        ? '選択していたQuestが利用できなくなりました。別のQuestを選択してください。'
        : _selectedMissionId != null && selectedMission == null
        ? '選択していたMissionが更新されました。もう一度Missionを選択してください。'
        : null;

    return QuestraModalSheet(
      title: 'Trailを残す',
      onDiscarded: _clearDraft,
      hasUnsavedChanges: () =>
          [
            _titleController,
            _summaryController,
            _contentController,
          ].any((controller) => controller.text.isNotEmpty) ||
          _selectedQuestId != null ||
          _selectedMissionId != null,
      isBusy: _isSaving,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.parent case final parent?) ...[
              const SizedBox(height: 12),
              _TrailParentBreadcrumb(parent: parent),
            ] else ...[
              const SizedBox(height: 12),
              if (unavailableParentMessage case final message?) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    key: const ValueKey('trail-parent-unavailable'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              QuestraFieldLabel(
                label: '1. Questを選ぶ',
                helper: '今回の一歩を残すQuestを選びます。',
                required: true,
                child: Semantics(
                  container: true,
                  label: 'Trailを紐づけるQuestを選択',
                  child: DropdownButtonFormField<String>(
                    key: const ValueKey('trail-quest-selector'),
                    initialValue: selectedQuest?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      hintText: 'Questを選択',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final quest in selectableQuests)
                        DropdownMenuItem(
                          value: quest.id,
                          child: Text(
                            quest.status == QuestStatus.completed
                                ? '${quest.title}（完了）'
                                : quest.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: selectableQuests.isEmpty
                        ? null
                        : (value) {
                            setState(() {
                              _selectedQuestId = value;
                              _selectedMissionId = null;
                              _errorMessage = null;
                            });
                            _scheduleDraftSave();
                          },
                    validator: (value) =>
                        value == null ? 'Trailを紐づけるQuestを選択してください。' : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              QuestraFieldLabel(
                label: '2. Missionを選ぶ',
                helper: '選んだQuestに紐づくMissionだけを表示します。',
                required: true,
                child: Semantics(
                  container: true,
                  label: selectedQuest == null
                      ? '先にTrailを紐づけるQuestを選択'
                      : '選択したQuestに紐づくMissionを選択',
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(
                      'trail-mission-selector-${selectedQuest?.id ?? 'none'}',
                    ),
                    initialValue: selectedMission?.id,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: selectedQuest == null
                          ? '先にQuestを選択'
                          : selectableMissions.isEmpty
                          ? '紐づけられるMissionがありません'
                          : 'Missionを選択',
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final mission in selectableMissions)
                        DropdownMenuItem(
                          value: mission.id,
                          child: Text(
                            mission.status == MissionStatus.completed
                                ? '${mission.title}（完了）'
                                : mission.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: selectableMissions.isEmpty
                        ? null
                        : (value) {
                            setState(() {
                              _selectedMissionId = value;
                              _errorMessage = null;
                            });
                            unawaited(
                              ref
                                  .read(analyticsServiceProvider)
                                  .trailJourney(
                                    name:
                                        AnalyticsEventName.trailParentSelected,
                                    surface: 'trail_composer',
                                    outcome: 'selected',
                                    hasQuest: selectedQuest != null,
                                    hasMission: value != null,
                                  ),
                            );
                            _scheduleDraftSave();
                          },
                    validator: (value) =>
                        value == null ? 'Questに紐づくMissionを選択してください。' : null,
                  ),
                ),
              ),
              if (selectedQuest != null && selectedMission != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  container: true,
                  label:
                      '保存先はQuest「${selectedQuest.title}」、Mission「${selectedMission.title}」です',
                  child: Column(
                    key: const ValueKey('trail-parent-selection-preview'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'この航路に記録します',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ExcludeSemantics(
                        child: _TrailParentBreadcrumb(
                          parent: TrailParentContext(
                            questId: selectedQuest.id,
                            questTitle: selectedQuest.title,
                            missionId: selectedMission.id,
                            missionTitle: selectedMission.title,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selectedMission.status == MissionStatus.completed) ...[
                  const SizedBox(height: 8),
                  Text(
                    '完了したMissionにも、振り返りや学びとしてTrailを残せます。',
                    key: const ValueKey('trail-completed-mission-guidance'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
              if (selectableQuests.isEmpty ||
                  (selectedQuest != null && selectableMissions.isEmpty)) ...[
                const SizedBox(height: 10),
                Text(
                  selectableQuests.isEmpty
                      ? '先にQuestとMissionを作成すると、その航路へTrailを残せます。'
                      : 'このQuestには利用できるMissionがありません。Quest画面でMissionを作成してください。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (selectedQuest != null &&
                    selectableMissions.isEmpty &&
                    widget.onOpenQuest != null) ...[
                  const SizedBox(height: 8),
                  Semantics(
                    button: true,
                    label: '選択したQuestでMission作成画面を開く',
                    child: TextButton.icon(
                      key: const ValueKey('trail-open-quest-for-mission'),
                      onPressed: () {
                        QuestraModalSheet.finish(context);
                        widget.onOpenQuest!(selectedQuest.id);
                      },
                      icon: const Icon(Icons.route_outlined),
                      label: const Text('QuestでMissionを作る'),
                    ),
                  ),
                ],
              ],
            ],
            const SizedBox(height: 16),
            if (_conflictingDraft != null) ...[
              Semantics(
                container: true,
                liveRegion: true,
                label: '別のQuestに保存中のTrail下書きがあります。',
                child: Container(
                  key: const ValueKey('trail-draft-context-conflict'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '別の航路に保存中の下書きがあります',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'どちらを続けるか選ぶまで、この画面から下書きを上書きしません。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (widget.parent == null)
                            OutlinedButton(
                              key: const ValueKey(
                                'trail-open-conflicting-draft',
                              ),
                              onPressed: _openConflictingDraft,
                              child: const Text('下書きを開く'),
                            )
                          else
                            OutlinedButton(
                              onPressed: () =>
                                  QuestraModalSheet.finish(context),
                              child: const Text('下書きを残して閉じる'),
                            ),
                          TextButton(
                            key: const ValueKey(
                              'trail-discard-conflicting-draft',
                            ),
                            onPressed: _discardConflictingDraft,
                            child: const Text('破棄してこの航路で続ける'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_draftRestored) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  '保存中の下書きを復元しました。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.draftOwnerId != null &&
                _draftSaveStatus != _TrailDraftSaveStatus.idle) ...[
              Semantics(
                liveRegion: true,
                label: _draftSaveStatus.message,
                child: Text(
                  _draftSaveStatus.message,
                  key: const ValueKey('trail-draft-save-status'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _draftSaveStatus == _TrailDraftSaveStatus.failed
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            QuestraFieldLabel(
              label: '今日の記録',
              required: true,
              child: TextFormField(
                key: const ValueKey('trail-quick-note'),
                controller: _summaryController,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: '進んだことや気づいたことを、短い言葉から残せます',
                  border: OutlineInputBorder(),
                ),
                maxLength: InputLimits.trailSummary,
                validator: (value) => InputValidators.requiredText(
                  value,
                  fieldName: '今日の記録',
                  maxLength: InputLimits.trailSummary,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() => _showDetails = !_showDetails);
                  _scheduleDraftSave();
                },
                icon: Icon(
                  _showDetails ? Icons.expand_less : Icons.expand_more,
                ),
                label: Text(_showDetails ? '詳細を閉じる' : 'タイトルや詳細も残す'),
              ),
            ),
            if (_showDetails) ...[
              const SizedBox(height: 4),
              QuestraFieldLabel(
                label: 'Trailのタイトル',
                helper: '空欄なら、今日の記録から自動で作成します。',
                child: TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: '例: 最初の一歩を終えた日',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: InputLimits.trailTitle,
                  validator: (value) => InputValidators.optionalText(
                    value,
                    fieldName: 'Trailのタイトル',
                    maxLength: InputLimits.trailTitle,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              QuestraFieldLabel(
                label: '詳しい記録',
                helper: '必要なときだけ、背景や次に試したいことを追加できます。',
                child: TextFormField(
                  controller: _contentController,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'できたこと、迷ったこと、次に試したいこと',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: InputLimits.trailContent,
                  validator: (value) => InputValidators.optionalText(
                    value,
                    fieldName: '詳しい記録',
                    maxLength: InputLimits.trailContent,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_errorMessage case final message?) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _isSaving ? null : _submit,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(_isSaving ? '保存しています...' : 'Trailを保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSaving || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    var saved = false;
    try {
      final summary = _summaryController.text.trim();
      final title = _titleController.text.trim();
      final content = _contentController.text.trim();
      final selectedQuest = ref
          .read(questControllerProvider)
          .where((quest) => quest.id == _selectedQuestId)
          .firstOrNull;
      final selectedMission = ref
          .read(missionControllerProvider)
          .where(
            (mission) =>
                mission.id == _selectedMissionId &&
                mission.questId == selectedQuest?.id &&
                mission.routeState != MissionRouteState.removed,
          )
          .firstOrNull;
      final parent =
          widget.parent ??
          (selectedQuest != null && selectedMission != null
              ? TrailParentContext(
                  questId: selectedQuest.id,
                  questTitle: selectedQuest.title,
                  missionId: selectedMission.id,
                  missionTitle: selectedMission.title,
                )
              : null);
      if (parent == null) {
        throw StateError('Trail parent selection is incomplete.');
      }
      saved = await widget.onSubmit(
        _TrailDraft(
          id: _draftId,
          title: title.isEmpty ? _deriveTitle(summary) : title,
          summary: summary,
          content: content.isEmpty ? summary : content,
          parent: parent,
        ),
      );
    } catch (_) {
      // Keep the draft and id stable so a retry cannot create a duplicate.
    }
    if (!mounted) return;
    if (saved) {
      await _clearDraft();
      if (!mounted) return;
      QuestraModalSheet.finish(context, true);
      return;
    }
    setState(() {
      _isSaving = false;
      _errorMessage = 'Trailを保存できませんでした。入力内容を残したまま再試行できます。';
    });
  }

  String _deriveTitle(String note) {
    final firstLine = note
        .split(RegExp(r'[。！？!?\r\n]+'))
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '今日のTrail');
    final compact = firstLine.replaceAll(RegExp(r'\s+'), ' ');
    return String.fromCharCodes(compact.runes.take(InputLimits.trailTitle));
  }

  void _applyRestoredDraft(TrailComposerDraft? draft) {
    if (draft == null) return;
    final quests = ref.read(questControllerProvider);
    final missions = ref.read(missionControllerProvider);
    final quest = draft.questId == null
        ? null
        : quests
              .where(
                (item) =>
                    item.id == draft.questId &&
                    item.status != QuestStatus.archived,
              )
              .firstOrNull;
    final mission = draft.missionId == null
        ? null
        : missions
              .where(
                (item) =>
                    item.id == draft.missionId &&
                    item.questId == quest?.id &&
                    item.routeState != MissionRouteState.removed,
              )
              .firstOrNull;
    final hasInvalidParent =
        (draft.questId != null && quest == null) ||
        (draft.missionId != null && mission == null);
    final fixedParent = widget.parent;
    final conflictsWithContext = fixedParent != null
        ? draft.questId != fixedParent.questId ||
              draft.missionId != fixedParent.missionId
        : widget.initialQuestId != null &&
              draft.questId != widget.initialQuestId;
    if (hasInvalidParent) {
      unawaited(_clearDraft());
      return;
    }
    if (conflictsWithContext) {
      _conflictingDraft = draft;
      return;
    }

    _restoreDraftValues(draft, fixedParent: fixedParent);
  }

  void _restoreDraftValues(
    TrailComposerDraft draft, {
    TrailParentContext? fixedParent,
  }) {
    _draftId = draft.id;
    if (fixedParent == null) {
      _selectedQuestId = draft.questId ?? _selectedQuestId;
      _selectedMissionId = draft.missionId ?? _selectedMissionId;
    }
    _titleController.text = draft.title;
    _summaryController.text = draft.summary;
    _contentController.text = draft.content;
    _showDetails =
        draft.showDetails || draft.title.isNotEmpty || draft.content.isNotEmpty;
    _draftRestored = true;
  }

  void _openConflictingDraft() {
    final draft = _conflictingDraft;
    if (draft == null || widget.parent != null) return;
    setState(() {
      _conflictingDraft = null;
      _restoreDraftValues(draft);
      _errorMessage = null;
    });
    _trackDraftConflict(outcome: 'opened_existing');
  }

  Future<void> _discardConflictingDraft() async {
    await _clearDraft();
    if (!mounted) return;
    setState(() {
      _conflictingDraft = null;
      _draftId = Trail.createId();
    });
    _trackDraftConflict(outcome: 'discarded_existing');
    _scheduleDraftSave();
  }

  void _trackDraftConflict({required String outcome}) {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .trailJourney(
            name: AnalyticsEventName.trailDraftConflictResolved,
            surface: 'trail_composer',
            outcome: outcome,
            hasQuest: _selectedQuestId != null,
            hasMission: _selectedMissionId != null,
          ),
    );
  }

  void _scheduleDraftSave() {
    if (_isSaving || _conflictingDraft != null || widget.draftOwnerId == null) {
      return;
    }
    _draftSaveTimer?.cancel();
    if (_draftSaveStatus != _TrailDraftSaveStatus.saving) {
      setState(() => _draftSaveStatus = _TrailDraftSaveStatus.saving);
    }
    _draftSaveTimer = Timer(const Duration(milliseconds: 300), _saveDraft);
  }

  void _saveDraft() {
    final ownerId = widget.draftOwnerId;
    if (ownerId == null) return;
    final parent = widget.parent;
    final draft = TrailComposerDraft(
      id: _draftId,
      questId: parent?.questId ?? _selectedQuestId,
      missionId: parent?.missionId ?? _selectedMissionId,
      title: _titleController.text,
      summary: _summaryController.text,
      content: _contentController.text,
      showDetails: _showDetails,
      updatedAt: DateTime.now(),
    );
    final repository = ref.read(trailDraftRepositoryProvider);
    final writeVersion = ++_draftWriteVersion;
    final operation = _pendingDraftWrite.then(
      (_) => repository.save(ownerId, draft),
    );
    _pendingDraftWrite = operation.catchError((_) {});
    unawaited(
      operation
          .then((_) {
            if (!mounted || writeVersion != _draftWriteVersion) return;
            setState(() => _draftSaveStatus = _TrailDraftSaveStatus.saved);
          })
          .catchError((_) {
            if (!mounted || writeVersion != _draftWriteVersion) return;
            setState(() => _draftSaveStatus = _TrailDraftSaveStatus.failed);
          }),
    );
  }

  Future<void> _clearDraft() async {
    final ownerId = widget.draftOwnerId;
    if (ownerId == null) return;
    _draftSaveTimer?.cancel();
    try {
      await _pendingDraftWrite;
      await ref.read(trailDraftRepositoryProvider).clear(ownerId);
      if (mounted) {
        setState(() => _draftSaveStatus = _TrailDraftSaveStatus.idle);
      }
    } catch (_) {
      // Draft cleanup must not block save or explicit dismissal.
    }
  }
}

extension on _TrailDraftSaveStatus {
  String get message => switch (this) {
    _TrailDraftSaveStatus.idle => '',
    _TrailDraftSaveStatus.saving => '下書きを保存しています...',
    _TrailDraftSaveStatus.saved => '下書きを保存しました。',
    _TrailDraftSaveStatus.failed => '下書きを保存できません。入力は画面に残っています。',
  };
}

int _compareTrailQuestChoice(Quest left, Quest right) {
  int rank(QuestStatus status) => switch (status) {
    QuestStatus.active => 0,
    QuestStatus.draft => 1,
    QuestStatus.completed => 2,
    QuestStatus.archived => 3,
  };

  final statusOrder = rank(left.status).compareTo(rank(right.status));
  if (statusOrder != 0) return statusOrder;
  return left.title.compareTo(right.title);
}

int _compareTrailMissionChoice(Mission left, Mission right) {
  final statusOrder = (left.status == MissionStatus.completed ? 1 : 0)
      .compareTo(right.status == MissionStatus.completed ? 1 : 0);
  if (statusOrder != 0) return statusOrder;

  final order = left.orderIndex.compareTo(right.orderIndex);
  if (order != 0) return order;

  final sortOrder = left.sortOrder.compareTo(right.sortOrder);
  if (sortOrder != 0) return sortOrder;

  return left.title.compareTo(right.title);
}

class _TrailOverview extends StatelessWidget {
  const _TrailOverview({required this.trails});

  final List<Trail> trails;

  @override
  Widget build(BuildContext context) {
    final questTrails = trails.where((trail) => trail.questId != null).length;
    final missionTrails = trails
        .where((trail) => trail.missionId != null)
        .length;
    final latestTrail = trails.isEmpty
        ? null
        : (trails.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
              .first;

    return QuestraCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('進捗の概要', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _TrailMetric(label: 'Trail', value: trails.length.toString()),
              _TrailMetric(label: 'Questに関連', value: questTrails.toString()),
              _TrailMetric(
                label: 'Missionに関連',
                value: missionTrails.toString(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            latestTrail == null
                ? 'QuestやMissionを進めて、最初のTrailを残しましょう。'
                : '最新: ${latestTrail.title} (${DateFormat.MMMd('ja').format(latestTrail.createdAt)})',
            style: const TextStyle(color: QuestraColors.slate),
          ),
        ],
      ),
    );
  }
}

class _TrailMetric extends StatelessWidget {
  const _TrailMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: QuestraColors.deepNavy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: QuestraColors.slate)),
        ],
      ),
    );
  }
}

class _TrailCard extends StatelessWidget {
  const _TrailCard({
    required this.trail,
    required this.parent,
    required this.attachment,
    required this.onEdit,
    required this.onReflect,
    required this.onAttachImage,
    required this.onReplaceImage,
    required this.onRemoveImage,
    required this.onShare,
    required this.onDelete,
    this.onOpenQuest,
    this.onOpenMission,
  });

  final Trail trail;
  final TrailParentContext? parent;
  final MediaAttachment? attachment;
  final VoidCallback onEdit;
  final VoidCallback onReflect;
  final VoidCallback onAttachImage;
  final VoidCallback? onReplaceImage;
  final VoidCallback? onRemoveImage;
  final VoidCallback? onShare;
  final VoidCallback onDelete;
  final VoidCallback? onOpenQuest;
  final VoidCallback? onOpenMission;

  @override
  Widget build(BuildContext context) {
    return QuestraCard(
      key: ValueKey('trail-entry-${trail.id}'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: QuestraColors.gold.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  trail.trailType.label,
                  style: const TextStyle(
                    color: QuestraColors.deepNavy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(DateFormat.MMMd('ja').format(trail.createdAt)),
                  QuestraPopupMenu<_TrailAction>(
                    tooltip: 'Trailメニュー',
                    onSelected: (action) {
                      switch (action) {
                        case _TrailAction.edit:
                          onEdit();
                        case _TrailAction.reflect:
                          onReflect();
                        case _TrailAction.attachImage:
                          onAttachImage();
                        case _TrailAction.replaceImage:
                          onReplaceImage?.call();
                        case _TrailAction.removeImage:
                          onRemoveImage?.call();
                        case _TrailAction.share:
                          onShare?.call();
                        case _TrailAction.delete:
                          onDelete();
                      }
                    },
                    items: [
                      const QuestraMenuItem(
                        value: _TrailAction.edit,
                        label: '編集',
                        icon: Icons.edit_outlined,
                      ),
                      const QuestraMenuItem(
                        value: _TrailAction.reflect,
                        label: '振り返る',
                        icon: Icons.auto_awesome_outlined,
                      ),
                      if (attachment == null)
                        const QuestraMenuItem(
                          value: _TrailAction.attachImage,
                          label: '画像を追加',
                          icon: Icons.add_photo_alternate_outlined,
                        )
                      else ...const [
                        QuestraMenuItem(
                          value: _TrailAction.replaceImage,
                          label: '画像を置換',
                          icon: Icons.find_replace_outlined,
                        ),
                        QuestraMenuItem(
                          value: _TrailAction.removeImage,
                          label: '画像を削除',
                          icon: Icons.hide_image_outlined,
                        ),
                      ],
                      if (onShare != null)
                        const QuestraMenuItem(
                          value: _TrailAction.share,
                          label: '選んで共有',
                          icon: Icons.ios_share_outlined,
                        ),
                      const QuestraMenuItem(
                        value: _TrailAction.delete,
                        label: 'Trailを削除',
                        icon: Icons.delete_outline,
                        destructive: true,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(trail.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(trail.summary),
          const SizedBox(height: 8),
          if (parent != null)
            _TrailParentBreadcrumb(
              parent: parent!,
              onOpenQuest: onOpenQuest,
              onOpenMission: onOpenMission,
            ),
          if (attachment != null) ...[
            const SizedBox(height: 10),
            _TrailImageAttachment(attachment: attachment!),
          ],
        ],
      ),
    );
  }
}

class _TrailParentBreadcrumb extends StatelessWidget {
  const _TrailParentBreadcrumb({
    required this.parent,
    this.onOpenQuest,
    this.onOpenMission,
  });

  final TrailParentContext parent;
  final VoidCallback? onOpenQuest;
  final VoidCallback? onOpenMission;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'このTrailに関連するQuest、Mission、Task',
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _HierarchyChip(
            key: ValueKey('trail-parent-quest-${parent.questId}'),
            label: 'Quest',
            value: parent.questTitle,
            onTap: onOpenQuest,
          ),
          if (parent.missionTitle case final title?) ...[
            const Icon(Icons.chevron_right, size: 16),
            _HierarchyChip(
              key: ValueKey('trail-parent-mission-${parent.missionId}'),
              label: 'Mission',
              value: title,
              onTap: onOpenMission,
            ),
          ],
          if (parent.taskTitle case final title?) ...[
            const Icon(Icons.chevron_right, size: 16),
            _HierarchyChip(label: 'Task', value: title),
          ],
        ],
      ),
    );
  }
}

class _HierarchyChip extends StatelessWidget {
  const _HierarchyChip({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: QuestraColors.cosmicBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: QuestraColors.cosmicBlue.withValues(alpha: 0.16),
        ),
      ),
      child: Text(
        '$label: $value',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: QuestraColors.deepNavy,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: '$label「$value」を開く',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: content,
        ),
      ),
    );
  }
}

class _TrailImageAttachment extends StatelessWidget {
  const _TrailImageAttachment({required this.attachment});

  final MediaAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final fileName = attachment.path.split('/').last;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: QuestraColors.cloud,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: QuestraColors.gold.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.image_outlined, color: QuestraColors.cosmicBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          const Text('非公開', style: TextStyle(color: QuestraColors.slate)),
        ],
      ),
    );
  }
}

class _ReflectTrailSheet extends StatefulWidget {
  const _ReflectTrailSheet({
    required this.trail,
    required this.coach,
    required this.onSubmit,
    this.mission,
  });

  final Trail trail;
  final Mission? mission;
  final ArcReflectionCoach coach;
  final Future<bool> Function(Trail) onSubmit;

  @override
  State<_ReflectTrailSheet> createState() => _ReflectTrailSheetState();
}

class _ReflectTrailSheetState extends State<_ReflectTrailSheet> {
  final _formKey = GlobalKey<FormState>();
  final _learningController = TextEditingController();
  final _nextStepController = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _learningController.dispose();
    _nextStepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return QuestraModalSheet(
      title: 'Trailを振り返る',
      hasUnsavedChanges: () =>
          _learningController.text.isNotEmpty ||
          _nextStepController.text.isNotEmpty,
      isBusy: _isSaving,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.trail.title),
            const SizedBox(height: 16),
            ArcPresence(
              surface: ArcPresenceSurface.reflection,
              emotion: widget.coach.emotion,
              message: widget.coach.message,
            ),
            const SizedBox(height: 16),
            QuestraFieldLabel(
              label: widget.coach.learningPrompt,
              required: true,
              child: TextFormField(
                controller: _learningController,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                maxLength: InputLimits.reflection,
                validator: (value) => InputValidators.requiredText(
                  value,
                  fieldName: '気づき',
                  maxLength: InputLimits.reflection,
                ),
              ),
            ),
            const SizedBox(height: 12),
            QuestraFieldLabel(
              label: widget.coach.nextMissionPrompt,
              required: true,
              child: TextFormField(
                controller: _nextStepController,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                maxLength: InputLimits.missionDescription,
                validator: (value) => InputValidators.requiredText(
                  value,
                  fieldName: '次のMission',
                  maxLength: InputLimits.missionDescription,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.coach.feedbackHint,
              style: const TextStyle(color: QuestraColors.slate),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isSaving ? null : _submit,
              icon: const Icon(Icons.auto_awesome),
              label: Text(_isSaving ? '保存しています...' : 'Reflectionを保存'),
            ),
            if (_errorMessage case final message?) ...[
              const SizedBox(height: 12),
              Semantics(liveRegion: true, child: Text(message)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSaving || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    final reflection = [
      widget.trail.content,
      '',
      if (widget.mission != null) 'Mission: ${widget.mission!.title}',
      'Reflection: ${_learningController.text.trim()}',
      'Next Mission: ${_nextStepController.text.trim()}',
      'Arc Coach: ${widget.coach.feedbackHint}',
    ].where((line) => line.trim().isNotEmpty).join('\n');
    var saved = false;
    try {
      saved = await widget.onSubmit(
        widget.trail.copyWith(
          summary: _learningController.text.trim(),
          content: reflection,
          trailType: TrailType.arcReflection,
        ),
      );
    } catch (_) {
      // Keep the reflection inputs visible for an explicit retry.
    }
    if (!mounted) return;
    if (saved) {
      QuestraModalSheet.finish(context);
      return;
    }
    setState(() {
      _isSaving = false;
      _errorMessage = '保存できませんでした。入力を残したまま再試行できます。';
    });
  }
}

class _EditTrailSheet extends ConsumerStatefulWidget {
  const _EditTrailSheet({required this.trail, required this.onSubmit});

  final Trail trail;
  final Future<TrailUpdateResult> Function(Trail) onSubmit;

  @override
  ConsumerState<_EditTrailSheet> createState() => _EditTrailSheetState();
}

class _EditTrailSheetState extends ConsumerState<_EditTrailSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _summaryController;
  late final TextEditingController _contentController;
  bool _isSaving = false;
  bool _isChangingParent = false;
  String? _errorMessage;
  late String? _selectedQuestId;
  late String? _selectedMissionId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.trail.title);
    _summaryController = TextEditingController(text: widget.trail.summary);
    _contentController = TextEditingController(text: widget.trail.content);
    _selectedQuestId = widget.trail.questId;
    _selectedMissionId = widget.trail.missionId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quests = ref.watch(questControllerProvider);
    final missions = ref.watch(missionControllerProvider);
    final currentQuest = quests
        .where((quest) => quest.id == widget.trail.questId)
        .firstOrNull;
    final currentMission = missions
        .where(
          (mission) =>
              mission.id == widget.trail.missionId &&
              mission.questId == widget.trail.questId,
        )
        .firstOrNull;
    final currentParent = currentQuest == null
        ? null
        : TrailParentContext(
            questId: currentQuest.id,
            questTitle: currentQuest.title,
            missionId: currentMission?.id,
            missionTitle: currentMission?.title,
          );
    final selectableQuests =
        quests
            .where((quest) => quest.status != QuestStatus.archived)
            .toList(growable: false)
          ..sort(_compareTrailQuestChoice);
    final selectedQuest = selectableQuests
        .where((quest) => quest.id == _selectedQuestId)
        .firstOrNull;
    final selectableMissions =
        missions
            .where(
              (mission) =>
                  mission.questId == selectedQuest?.id &&
                  mission.routeState != MissionRouteState.removed,
            )
            .toList(growable: false)
          ..sort(_compareTrailMissionChoice);
    final selectedMission = selectableMissions
        .where((mission) => mission.id == _selectedMissionId)
        .firstOrNull;
    final parentChanged =
        _isChangingParent &&
        (_selectedQuestId != widget.trail.questId ||
            _selectedMissionId != widget.trail.missionId);

    return QuestraModalSheet(
      title: 'Trailを編集',
      hasUnsavedChanges: () =>
          _titleController.text != widget.trail.title ||
          _summaryController.text != widget.trail.summary ||
          _contentController.text != widget.trail.content ||
          parentChanged,
      isBusy: _isSaving,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentParent != null) ...[
              QuestraFieldLabel(
                label: '紐づけ先',
                helper: widget.trail.taskId == null
                    ? 'このTrailを残したQuestとMissionです。'
                    : 'Taskから残したTrailの航路は、履歴保護のため変更できません。',
                child: _TrailParentBreadcrumb(parent: currentParent),
              ),
              if (widget.trail.taskId == null && !_isChangingParent)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('trail-edit-change-parent'),
                    onPressed: () => setState(() {
                      _isChangingParent = true;
                      _errorMessage = null;
                    }),
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('紐づけ先を変更'),
                  ),
                ),
              const SizedBox(height: 12),
            ],
            if (_isChangingParent && widget.trail.taskId == null) ...[
              QuestraFieldLabel(
                label: '変更後のQuest',
                required: true,
                child: DropdownButtonFormField<String>(
                  key: const ValueKey('trail-edit-quest-selector'),
                  initialValue: selectedQuest?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    hintText: 'Questを選択',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final quest in selectableQuests)
                      DropdownMenuItem(
                        value: quest.id,
                        child: Text(
                          quest.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _selectedQuestId = value;
                    _selectedMissionId = null;
                    _errorMessage = null;
                  }),
                  validator: (value) =>
                      value == null ? '変更後のQuestを選択してください。' : null,
                ),
              ),
              const SizedBox(height: 12),
              QuestraFieldLabel(
                label: '変更後のMission',
                helper: '選んだQuestに紐づくMissionだけを表示します。',
                required: true,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(
                    'trail-edit-mission-selector-${selectedQuest?.id ?? 'none'}',
                  ),
                  initialValue: selectedMission?.id,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: selectedQuest == null
                        ? '先にQuestを選択'
                        : selectableMissions.isEmpty
                        ? '紐づけられるMissionがありません'
                        : 'Missionを選択',
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final mission in selectableMissions)
                      DropdownMenuItem(
                        value: mission.id,
                        child: Text(
                          mission.status == MissionStatus.completed
                              ? '${mission.title}（完了）'
                              : mission.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: selectableMissions.isEmpty
                      ? null
                      : (value) => setState(() {
                          _selectedMissionId = value;
                          _errorMessage = null;
                        }),
                  validator: (value) =>
                      value == null ? '変更後のMissionを選択してください。' : null,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() {
                    _isChangingParent = false;
                    _selectedQuestId = widget.trail.questId;
                    _selectedMissionId = widget.trail.missionId;
                    _errorMessage = null;
                  }),
                  child: const Text('変更をやめる'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            QuestraFieldLabel(
              label: 'Trailの名前',
              required: true,
              child: TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                maxLength: InputLimits.trailTitle,
                validator: (value) => InputValidators.requiredText(
                  value,
                  fieldName: 'Trail名',
                  maxLength: InputLimits.trailTitle,
                ),
              ),
            ),
            const SizedBox(height: 12),
            QuestraFieldLabel(
              label: 'ひとことで振り返る',
              required: true,
              child: TextFormField(
                controller: _summaryController,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                maxLength: InputLimits.trailSummary,
                validator: (value) => InputValidators.requiredText(
                  value,
                  fieldName: '要約',
                  maxLength: InputLimits.trailSummary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            QuestraFieldLabel(
              label: '詳しい記録',
              required: true,
              child: TextFormField(
                controller: _contentController,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                minLines: 3,
                maxLines: 5,
                maxLength: InputLimits.trailContent,
                validator: (value) => InputValidators.requiredText(
                  value,
                  fieldName: '記録',
                  maxLength: InputLimits.trailContent,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isSaving ? null : _submit,
              icon: const Icon(Icons.check),
              label: Text(_isSaving ? '保存しています...' : '変更を保存'),
            ),
            if (_errorMessage case final message?) ...[
              const SizedBox(height: 12),
              Semantics(liveRegion: true, child: Text(message)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSaving || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    TrailUpdateResult? result;
    try {
      var updatedTrail = widget.trail.copyWith(
        title: _titleController.text.trim(),
        summary: _summaryController.text.trim(),
        content: _contentController.text.trim(),
      );
      if (_isChangingParent && widget.trail.taskId == null) {
        final selectedQuest = ref
            .read(questControllerProvider)
            .where(
              (quest) =>
                  quest.id == _selectedQuestId &&
                  quest.status != QuestStatus.archived,
            )
            .firstOrNull;
        final selectedMission = ref
            .read(missionControllerProvider)
            .where(
              (mission) =>
                  mission.id == _selectedMissionId &&
                  mission.questId == selectedQuest?.id &&
                  mission.routeState != MissionRouteState.removed,
            )
            .firstOrNull;
        if (selectedQuest == null || selectedMission == null) {
          throw StateError('Trail parent selection is incomplete.');
        }
        updatedTrail = updatedTrail.copyWithParent(
          questId: selectedQuest.id,
          missionId: selectedMission.id,
        );
      }
      result = await widget.onSubmit(updatedTrail);
    } catch (_) {
      // Keep the edited fields visible for an explicit retry.
    }
    if (!mounted) return;
    if (result?.isSaved ?? false) {
      QuestraModalSheet.finish(context);
      return;
    }
    setState(() {
      _isSaving = false;
      _errorMessage = result?.message ?? '保存できませんでした。入力を残したまま再試行できます。';
    });
  }
}

PersistenceSyncState _toPersistenceState(TrailSyncState state) {
  final status = switch (state.status) {
    TrailSyncStatus.idle => PersistenceSyncStatus.idle,
    TrailSyncStatus.loading => PersistenceSyncStatus.loading,
    TrailSyncStatus.saved => PersistenceSyncStatus.saved,
    TrailSyncStatus.failed => PersistenceSyncStatus.failed,
  };
  final operation = switch (state.operation) {
    TrailSyncOperation.load => PersistenceSyncOperation.load,
    TrailSyncOperation.save ||
    TrailSyncOperation.media => PersistenceSyncOperation.save,
    TrailSyncOperation.delete => PersistenceSyncOperation.delete,
    TrailSyncOperation.unknown => PersistenceSyncOperation.unknown,
  };
  return PersistenceSyncState(
    status: status,
    message: state.message,
    operation: operation,
    retryAvailable: state.retryAvailable,
    inputPreserved: state.inputPreserved,
    offline: state.offline,
  );
}

enum _TrailAction {
  edit,
  reflect,
  attachImage,
  replaceImage,
  removeImage,
  share,
  delete,
}
