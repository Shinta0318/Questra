import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/performance/performance_limits.dart';
import '../../core/theme/questra_colors.dart';
import '../../core/validation/input_validators.dart';
import '../../widgets/forms/questra_field_label.dart';
import '../../widgets/arc/arc_presence.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/menu/questra_action_menu.dart';
import '../../widgets/questra_card.dart';
import '../arc/arc_celebration_service.dart';
import '../arc/arc_guidance_providers.dart';
import '../arc/arc_reflection_coach_service.dart';
import '../auth/auth_controller.dart';
import '../media/media_model.dart';
import '../mission/mission_controller.dart';
import '../mission/mission_model.dart';
import '../task/task_controller.dart';
import '../task/task_model.dart';
import 'trail_controller.dart';
import 'trail_highlight_service.dart';
import 'trail_model.dart';
import 'trail_sync_state.dart';
import 'trail_timeline_widget.dart';

final trailHighlightServiceProvider = Provider<TrailHighlightService>((ref) {
  return const TrailHighlightService();
});

class TrailScreen extends ConsumerStatefulWidget {
  const TrailScreen({super.key, this.initialParent, this.openComposer = false});

  final TrailParentContext? initialParent;
  final bool openComposer;

  @override
  ConsumerState<TrailScreen> createState() => _TrailScreenState();
}

class _TrailScreenState extends ConsumerState<TrailScreen> {
  bool _didOpenComposer = false;

  @override
  Widget build(BuildContext context) {
    final trails = ref.watch(trailControllerProvider);
    final missions = ref.watch(missionControllerProvider);
    final tasks = ref.watch(taskControllerProvider);
    final trailMedia = ref.watch(trailMediaControllerProvider);
    final syncState = ref.watch(trailSyncControllerProvider);
    final profile = ref.watch(authControllerProvider).profile;
    final controller = ref.read(trailControllerProvider.notifier);
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

    if (widget.openComposer && !_didOpenComposer) {
      _didOpenComposer = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showCreateTrailSheet(
          context,
          ref.read(trailControllerProvider.notifier),
          parent: widget.initialParent,
        );
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Trail')),
      body: SafeArea(
        child: QuestraResponsiveListView(
          showScrollbar: true,
          onRefresh: profile == null
              ? null
              : () => controller.loadForUser(profile.id),
          padding: const EdgeInsets.all(20),
          children: [
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
              ),
              icon: const Icon(Icons.add),
              label: Text(trails.isEmpty ? '最初のTrailを残す' : 'Trailを残す'),
            ),
            const SizedBox(height: 16),
            if (syncState.status != TrailSyncStatus.idle) ...[
              _TrailSyncBanner(
                state: syncState,
                onRetry: profile == null
                    ? null
                    : () => controller.loadForUser(profile.id),
                onDismiss: () =>
                    ref.read(trailSyncControllerProvider.notifier).clear(),
              ),
              const SizedBox(height: 12),
            ],
            _TrailOverview(trails: trails),
            const SizedBox(height: 16),
            TrailTimelineWidget(
              trails: trails,
              attachments: trailMedia,
              highlights: {
                for (final highlight in trailHighlights)
                  highlight.trailId: highlight,
              },
              hierarchyByTrailId: hierarchyByTrailId,
            ),
            const SizedBox(height: 16),
            ...trails.map(
              (trail) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TrailCard(
                  trail: trail,
                  parent: hierarchyByTrailId[trail.id],
                  attachment: trailMedia[trail.id],
                  onEdit: () => _showEditTrailSheet(context, controller, trail),
                  onReflect: () => _showReflectTrailSheet(
                    context,
                    ref,
                    controller,
                    trail,
                    _missionForTrail(trail, missions),
                  ),
                  onAttachImage: () =>
                      _attachTrailImage(context, controller, trail),
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
                  onDelete: () =>
                      _confirmDeleteTrail(context, controller, trail),
                ),
              ),
            ),
          ],
        ),
      ),
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

  void _showCreateTrailSheet(
    BuildContext context,
    TrailController controller, {
    TrailParentContext? parent,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CreateTrailSheet(
        parent: parent,
        onSubmit: (draft) => controller.addManualTrailAndWait(
          trailId: draft.id,
          title: draft.title,
          summary: draft.summary,
          content: draft.content,
          parent: parent,
        ),
      ),
    );
  }

  void _showEditTrailSheet(
    BuildContext context,
    TrailController controller,
    Trail trail,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _EditTrailSheet(trail: trail, onSubmit: controller.updateTrail),
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ReflectTrailSheet(
        trail: trail,
        mission: mission,
        coach: coach,
        onSubmit: (updatedTrail) {
          controller.updateTrail(updatedTrail);
          showArcCelebrationSnackBar(
            context,
            ref
                .read(arcCelebrationServiceProvider)
                .build(
                  event: ArcCelebrationEvent.trailReflection,
                  subject: updatedTrail.title,
                ),
          );
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
      controller.removeTrail(trail.id);
    }
  }
}

class _TrailDraft {
  const _TrailDraft({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
  });

  final String id;
  final String title;
  final String summary;
  final String content;
}

class _CreateTrailSheet extends StatefulWidget {
  const _CreateTrailSheet({required this.onSubmit, this.parent});

  final Future<bool> Function(_TrailDraft) onSubmit;
  final TrailParentContext? parent;

  @override
  State<_CreateTrailSheet> createState() => _CreateTrailSheetState();
}

class _CreateTrailSheetState extends State<_CreateTrailSheet> {
  final _formKey = GlobalKey<FormState>();
  final String _draftId = Trail.createId();
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trailを残す',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (widget.parent case final parent?) ...[
                  const SizedBox(height: 12),
                  _TrailParentBreadcrumb(parent: parent),
                ],
                const SizedBox(height: 16),
                QuestraFieldLabel(
                  label: 'Trailの名前',
                  required: true,
                  child: TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: '例: 最初の一歩を終えた日',
                      border: OutlineInputBorder(),
                    ),
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
                    decoration: const InputDecoration(
                      hintText: '今日進んだことを短く',
                      border: OutlineInputBorder(),
                    ),
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
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: 'できたこと、迷ったこと、次に試したいこと',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: InputLimits.trailContent,
                    validator: (value) => InputValidators.requiredText(
                      value,
                      fieldName: '記録',
                      maxLength: InputLimits.trailContent,
                    ),
                  ),
                ),
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
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    final saved = await widget.onSubmit(
      _TrailDraft(
        id: _draftId,
        title: _titleController.text.trim(),
        summary: _summaryController.text.trim(),
        content: _contentController.text.trim(),
      ),
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _isSaving = false;
      _errorMessage = 'Trailを保存できませんでした。入力内容を残したまま再試行できます。';
    });
  }
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
              _TrailMetric(label: 'Questとの紐づき', value: questTrails.toString()),
              _TrailMetric(
                label: 'Missionとの紐づき',
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
    required this.onDelete,
  });

  final Trail trail;
  final TrailParentContext? parent;
  final MediaAttachment? attachment;
  final VoidCallback onEdit;
  final VoidCallback onReflect;
  final VoidCallback onAttachImage;
  final VoidCallback? onReplaceImage;
  final VoidCallback? onRemoveImage;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return QuestraCard(
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
            _TrailParentBreadcrumb(parent: parent!)
          else
            const Text(
              'Questに紐づかないTrail',
              style: TextStyle(color: QuestraColors.slate),
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
  const _TrailParentBreadcrumb({required this.parent});

  final TrailParentContext parent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Trailの紐づけ',
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _HierarchyChip(label: 'Quest', value: parent.questTitle),
          if (parent.missionTitle case final title?) ...[
            const Icon(Icons.chevron_right, size: 16),
            _HierarchyChip(label: 'Mission', value: title),
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
  const _HierarchyChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
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
  final ValueChanged<Trail> onSubmit;

  @override
  State<_ReflectTrailSheet> createState() => _ReflectTrailSheetState();
}

class _ReflectTrailSheetState extends State<_ReflectTrailSheet> {
  final _formKey = GlobalKey<FormState>();
  final _learningController = TextEditingController();
  final _nextStepController = TextEditingController();

  @override
  void dispose() {
    _learningController.dispose();
    _nextStepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trailを振り返る',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
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
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
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
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
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
                  onPressed: _submit,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Reflectionを保存'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final reflection = [
      widget.trail.content,
      '',
      if (widget.mission != null) 'Mission: ${widget.mission!.title}',
      'Reflection: ${_learningController.text.trim()}',
      'Next Mission: ${_nextStepController.text.trim()}',
      'Arc Coach: ${widget.coach.feedbackHint}',
    ].where((line) => line.trim().isNotEmpty).join('\n');
    widget.onSubmit(
      widget.trail.copyWith(
        summary: _learningController.text.trim(),
        content: reflection,
        trailType: TrailType.arcReflection,
      ),
    );
    Navigator.of(context).pop();
  }
}

class _EditTrailSheet extends StatefulWidget {
  const _EditTrailSheet({required this.trail, required this.onSubmit});

  final Trail trail;
  final ValueChanged<Trail> onSubmit;

  @override
  State<_EditTrailSheet> createState() => _EditTrailSheetState();
}

class _EditTrailSheetState extends State<_EditTrailSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _summaryController;
  late final TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.trail.title);
    _summaryController = TextEditingController(text: widget.trail.summary);
    _contentController = TextEditingController(text: widget.trail.content);
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trailを編集',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                QuestraFieldLabel(
                  label: 'Trailの名前',
                  required: true,
                  child: TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
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
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
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
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
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
                  onPressed: _submit,
                  icon: const Icon(Icons.check),
                  label: const Text('変更を保存'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    widget.onSubmit(
      widget.trail.copyWith(
        title: _titleController.text.trim(),
        summary: _summaryController.text.trim(),
        content: _contentController.text.trim(),
      ),
    );
    Navigator.of(context).pop();
  }
}

class _TrailSyncBanner extends StatelessWidget {
  const _TrailSyncBanner({
    required this.state,
    required this.onRetry,
    required this.onDismiss,
  });

  final TrailSyncState state;
  final VoidCallback? onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isFailed = state.status == TrailSyncStatus.failed;
    final isLoading = state.status == TrailSyncStatus.loading;

    return QuestraCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          if (isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              isFailed ? Icons.error_outline : Icons.cloud_done_outlined,
              color: isFailed ? Colors.redAccent : QuestraColors.cosmicBlue,
            ),
          const SizedBox(width: 12),
          Expanded(child: Text(state.message ?? 'Trailの同期状態を更新しました。')),
          if (isFailed && onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('再試行')),
          IconButton(
            tooltip: '閉じる',
            onPressed: onDismiss,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

enum _TrailAction {
  edit,
  reflect,
  attachImage,
  replaceImage,
  removeImage,
  delete,
}
