import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/performance/performance_limits.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/questra_colors.dart';
import '../../widgets/arc/arc_empty_state.dart';
import '../../widgets/arc/arc_presence.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/questra_card.dart';
import '../arc/arc_celebration_service.dart';
import '../arc/arc_expression_engine.dart';
import '../arc/arc_guidance_providers.dart';
import '../arc/arc_reflection_coach_service.dart';
import '../auth/auth_controller.dart';
import '../media/media_model.dart';
import '../mission/mission_controller.dart';
import '../mission/mission_model.dart';
import 'trail_controller.dart';
import 'trail_highlight_service.dart';
import 'trail_model.dart';
import 'trail_sync_state.dart';
import 'trail_timeline_widget.dart';

final trailHighlightServiceProvider = Provider<TrailHighlightService>((ref) {
  return const TrailHighlightService();
});

class TrailScreen extends ConsumerWidget {
  const TrailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trails = ref.watch(trailControllerProvider);
    final missions = ref.watch(missionControllerProvider);
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

    return Scaffold(
      appBar: AppBar(title: const Text('Trail')),
      body: SafeArea(
        child: QuestraResponsiveListView(
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
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _showCreateTrailSheet(context, controller),
              icon: const Icon(Icons.add),
              label: const Text('Trailを残す'),
            ),
            const SizedBox(height: 16),
            if (trails.isEmpty)
              ArcEmptyState(
                title: 'まだTrailがありません',
                emotion: expressionEngine
                    .resolve(
                      const ArcExpressionContext(
                        moment: ArcExpressionMoment.empty,
                      ),
                    )
                    .emotion,
                message: 'Missionを完了するかQuestにTrailを残すと、ここに進み方が並びます。',
                actionLabel: 'Questへ戻る',
                icon: Icons.timeline_outlined,
                onAction: () => context.go(AppRoutes.quest),
              ),
            ...trails.map(
              (trail) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TrailCard(
                  trail: trail,
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
        title: const Text('Remove image?'),
        content: Text('Remove the image attached to "${trail.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
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

  void _showCreateTrailSheet(BuildContext context, TrailController controller) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CreateTrailSheet(
        onSubmit: (draft) {
          controller.addManualTrail(
            title: draft.title,
            summary: draft.summary,
            content: draft.content,
          );
        },
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
        title: const Text('Delete Trail?'),
        content: Text('Remove "${trail.title}" from your Trail records?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
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
    required this.title,
    required this.summary,
    required this.content,
  });

  final String title;
  final String summary;
  final String content;
}

class _CreateTrailSheet extends StatefulWidget {
  const _CreateTrailSheet({required this.onSubmit});

  final ValueChanged<_TrailDraft> onSubmit;

  @override
  State<_CreateTrailSheet> createState() => _CreateTrailSheetState();
}

class _CreateTrailSheetState extends State<_CreateTrailSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _contentController = TextEditingController();

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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _summaryController,
                  decoration: const InputDecoration(
                    labelText: 'Summary',
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contentController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.add),
                  label: const Text('Save Trail'),
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
      _TrailDraft(
        title: _titleController.text.trim(),
        summary: _summaryController.text.trim(),
        content: _contentController.text.trim(),
      ),
    );
    Navigator.of(context).pop();
  }
}

String? _required(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Required';
  }
  return null;
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
          Text(
            'Progress Overview',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _TrailMetric(label: 'Trails', value: trails.length.toString()),
              _TrailMetric(label: 'Quest links', value: questTrails.toString()),
              _TrailMetric(
                label: 'Mission links',
                value: missionTrails.toString(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            latestTrail == null
                ? 'The first Trail will appear after a Mission or Quest step.'
                : 'Latest: ${latestTrail.title} (${DateFormat.MMMd('ja').format(latestTrail.createdAt)})',
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
    required this.attachment,
    required this.onEdit,
    required this.onReflect,
    required this.onAttachImage,
    required this.onReplaceImage,
    required this.onRemoveImage,
    required this.onDelete,
  });

  final Trail trail;
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
                  PopupMenuButton<_TrailAction>(
                    tooltip: 'Trail actions',
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
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: _TrailAction.edit,
                        child: Text('Edit'),
                      ),
                      const PopupMenuItem(
                        value: _TrailAction.reflect,
                        child: Text('Reflect'),
                      ),
                      if (attachment == null)
                        const PopupMenuItem(
                          value: _TrailAction.attachImage,
                          child: Text('Attach image'),
                        )
                      else ...const [
                        PopupMenuItem(
                          value: _TrailAction.replaceImage,
                          child: Text('Replace image'),
                        ),
                        PopupMenuItem(
                          value: _TrailAction.removeImage,
                          child: Text('Remove image'),
                        ),
                      ],
                      const PopupMenuItem(
                        value: _TrailAction.delete,
                        child: Text('Delete'),
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
          Text(
            trail.questId == null
                ? 'Quest: Unlinked'
                : 'Quest: ${trail.questId}',
            style: const TextStyle(color: QuestraColors.slate),
          ),
          if (trail.missionId != null)
            Text(
              'Mission: ${trail.missionId}',
              style: const TextStyle(color: QuestraColors.slate),
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
          const Text('Private', style: TextStyle(color: QuestraColors.slate)),
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
                TextFormField(
                  controller: _learningController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: widget.coach.learningPrompt,
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nextStepController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: widget.coach.nextMissionPrompt,
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
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
                  'Edit Trail',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _summaryController,
                  decoration: const InputDecoration(
                    labelText: 'Summary',
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 3,
                  maxLines: 5,
                  validator: _required,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check),
                  label: const Text('Save Trail'),
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
          Expanded(child: Text(state.message ?? 'Trail sync updated.')),
          if (isFailed && onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          IconButton(
            tooltip: 'Dismiss',
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
