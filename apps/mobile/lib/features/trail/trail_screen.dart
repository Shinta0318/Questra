import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/questra_colors.dart';
import '../../widgets/questra_card.dart';
import '../auth/auth_controller.dart';
import 'trail_controller.dart';
import 'trail_model.dart';
import 'trail_sync_state.dart';

class TrailScreen extends ConsumerWidget {
  const TrailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trails = ref.watch(trailControllerProvider);
    final syncState = ref.watch(trailSyncControllerProvider);
    final profile = ref.watch(authControllerProvider).profile;
    final controller = ref.read(trailControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Trail')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            QuestraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trail',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Trail links Quests, Missions, and Arc reflections into a path you can return to.',
                  ),
                ],
              ),
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
            if (trails.isEmpty)
              const QuestraCard(
                child: Text('Missionを完了するかQuestにTrailを残すと、ここに進み方が並びます。'),
              ),
            ...trails.map(
              (trail) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TrailCard(
                  trail: trail,
                  onEdit: () => _showEditTrailSheet(context, controller, trail),
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
    required this.onEdit,
    required this.onDelete,
  });

  final Trail trail;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return QuestraCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              const Spacer(),
              Text(DateFormat.MMMd('ja').format(trail.createdAt)),
              PopupMenuButton<_TrailAction>(
                tooltip: 'Trail actions',
                onSelected: (action) {
                  switch (action) {
                    case _TrailAction.edit:
                      onEdit();
                    case _TrailAction.delete:
                      onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: _TrailAction.edit, child: Text('Edit')),
                  PopupMenuItem(
                    value: _TrailAction.delete,
                    child: Text('Delete'),
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
        ],
      ),
    );
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

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
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

enum _TrailAction { edit, delete }
