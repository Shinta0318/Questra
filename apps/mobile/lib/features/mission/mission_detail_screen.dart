import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/router/app_routes.dart';
import '../../widgets/forms/questra_field_label.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/questra_card.dart';
import '../task/task_controller.dart';
import '../task/task_generation_service.dart';
import '../task/task_model.dart';
import '../task/task_mutation_banner.dart';
import '../task/task_mutation_state.dart';
import '../task/task_progress_service.dart';
import 'mission_controller.dart';
import 'mission_model.dart';

class MissionDetailScreen extends ConsumerStatefulWidget {
  const MissionDetailScreen({required this.missionId, super.key});
  final String missionId;

  @override
  ConsumerState<MissionDetailScreen> createState() =>
      _MissionDetailScreenState();
}

class _MissionDetailScreenState extends ConsumerState<MissionDetailScreen> {
  bool _isGenerating = false;
  String? _generationError;

  @override
  Widget build(BuildContext context) {
    final mission = ref
        .watch(missionControllerProvider)
        .where((item) => item.id == widget.missionId)
        .firstOrNull;
    final tasks =
        ref
            .watch(taskControllerProvider)
            .where((task) => task.missionId == widget.missionId)
            .toList()
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    if (mission == null) {
      return const Scaffold(body: Center(child: Text('Missionが見つかりません。')));
    }
    final taskProgress = const TaskProgressService().forMission(tasks);
    final taskMutation = ref.watch(taskMutationControllerProvider);
    final canConfirm =
        taskProgress.allRequiredCompleted && mission.successConfirmedAt == null;
    return Scaffold(
      appBar: AppBar(title: const Text('Mission')),
      body: QuestraResponsiveListView(
        padding: const EdgeInsets.all(20),
        children: [
          TaskMutationBanner(
            state: taskMutation,
            onRetry: () async {
              await ref.read(taskControllerProvider.notifier).retryPending();
            },
            onDiscard: () =>
                ref.read(taskControllerProvider.notifier).discardPending(),
            onDismiss: () =>
                ref.read(taskMutationControllerProvider.notifier).clear(),
          ),
          if (taskMutation.isActive) const SizedBox(height: 12),
          Text(
            'QUEST  ${mission.questTitle}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          const Text('MISSION', style: TextStyle(fontWeight: FontWeight.w900)),
          Text(mission.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            mission.objective.isNotEmpty
                ? mission.objective
                : mission.description,
          ),
          const SizedBox(height: 16),
          QuestraCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'このMissionで達成すること',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  mission.objective.isNotEmpty
                      ? mission.objective
                      : mission.description,
                ),
                const SizedBox(height: 12),
                Text(
                  'Mission完了条件\n${mission.successCondition.isNotEmpty ? mission.successCondition : mission.doneCondition}',
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: taskProgress.percent / 100),
                const SizedBox(height: 6),
                Text(
                  !taskProgress.hasTasks
                      ? 'Taskはまだありません'
                      : taskProgress.hasOptionalTasksOnly
                      ? '任意Taskのみ・成果を確認できます'
                      : '必須Task ${taskProgress.completed} / ${taskProgress.total} 完了',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => context.push(
                  AppRoutes.arcForMission(
                    questId: mission.questId,
                    missionId: mission.id,
                    prompt: '「${mission.title}」を進める次の一歩を相談したい。',
                    returnTo: AppRoutes.missionDetail(
                      mission.questId,
                      mission.id,
                    ),
                  ),
                ),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Arcに相談'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push(
                  AppRoutes.missionSupport(mission.questId, mission.id),
                ),
                icon: const Icon(Icons.travel_explore_outlined),
                label: const Text('実行サポート'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'このMissionを進めるTask',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (tasks.isEmpty) ...[
            QuestraCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.route_outlined, size: 30),
                  const SizedBox(height: 10),
                  Text(
                    '最初の一歩を決めよう',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text('Arcから具体的な行動を提案してもらうか、自分でTaskを追加できます。'),
                  if (_generationError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _generationError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _TaskActions(
                    isGenerating: _isGenerating,
                    onGenerate: () => _generateTasks(mission, tasks),
                    onManualAdd: () => _addManualTask(mission, tasks),
                  ),
                ],
              ),
            ),
          ] else ...[
            for (final task in tasks) _TaskTile(task: task),
            const SizedBox(height: 6),
            _TaskActions(
              isGenerating: _isGenerating,
              onGenerate: () => _generateTasks(mission, tasks),
              onManualAdd: () => _addManualTask(mission, tasks),
            ),
            if (_generationError != null) ...[
              const SizedBox(height: 8),
              Text(
                _generationError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: canConfirm
                ? () => ref
                      .read(missionControllerProvider.notifier)
                      .confirmMissionSuccess(
                        mission.id,
                        allRequiredTasksCompleted:
                            taskProgress.allRequiredCompleted,
                      )
                : null,
            icon: const Icon(Icons.verified_outlined),
            label: Text(
              mission.successConfirmedAt != null
                  ? 'Mission達成を確認済み'
                  : '成果を確認してMission達成',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateTasks(
    Mission mission,
    List<QuestraTask> existing,
  ) async {
    if (_isGenerating) return;
    setState(() {
      _isGenerating = true;
      _generationError = null;
    });
    try {
      final suggestions = await ref
          .read(taskGenerationServiceProvider)
          .generateForMission(mission);
      if (!mounted) return;
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => _TaskSuggestionDialog(suggestions: suggestions),
      );
      if (approved != true || !mounted) return;
      await _saveSuggestions(mission, existing, suggestions);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _generationError = error
            .toString()
            .replaceFirst('Bad state: ', '')
            .replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _saveSuggestions(
    Mission mission,
    List<QuestraTask> existing,
    List<TaskSuggestion> suggestions,
  ) async {
    final existingKeys = existing
        .map((task) => '${task.title.trim()}\n${task.action.trim()}')
        .toSet();
    final accepted = suggestions
        .where(
          (item) => !existingKeys.contains(
            '${item.title.trim()}\n${item.action.trim()}',
          ),
        )
        .toList(growable: false);
    if (accepted.isEmpty) {
      throw StateError('同じ内容のTaskがすでにあります。');
    }
    const uuid = Uuid();
    final ids = {
      for (final suggestion in accepted) suggestion.clientId: uuid.v4(),
    };
    final firstOrder = existing.isEmpty
        ? 0
        : existing
                  .map((task) => task.orderIndex)
                  .reduce((a, b) => a > b ? a : b) +
              1;
    final tasks = <QuestraTask>[];
    for (var index = 0; index < accepted.length; index++) {
      final suggestion = accepted[index];
      tasks.add(
        QuestraTask(
          id: ids[suggestion.clientId],
          questId: mission.questId,
          questTitle: mission.questTitle,
          missionId: mission.id,
          missionTitle: mission.title,
          title: suggestion.title,
          action: suggestion.action,
          purpose: suggestion.purpose,
          doneCondition: suggestion.doneCondition,
          expectedOutput: suggestion.expectedOutput,
          estimatedEffortMinutes: suggestion.estimatedEffortMinutes,
          required: suggestion.required,
          orderIndex: firstOrder + index,
          dependencyIds: suggestion.dependencyClientIds
              .map((id) => ids[id])
              .whereType<String>()
              .toList(growable: false),
          generatedBy: TaskGeneratedBy.arc,
          generationVersion: 'qst-261-v1',
        ),
      );
    }
    await ref.read(taskControllerProvider.notifier).addTasks(tasks);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${tasks.length}件のTaskを追加しました。')));
  }

  Future<void> _addManualTask(
    Mission mission,
    List<QuestraTask> existing,
  ) async {
    final draft = await showDialog<_ManualTaskDraft>(
      context: context,
      builder: (context) => const _ManualTaskDialog(),
    );
    if (draft == null || !mounted) return;
    try {
      await ref
          .read(taskControllerProvider.notifier)
          .addTask(
            QuestraTask(
              questId: mission.questId,
              questTitle: mission.questTitle,
              missionId: mission.id,
              missionTitle: mission.title,
              title: draft.title,
              action: draft.action,
              purpose: mission.objective.isNotEmpty
                  ? mission.objective
                  : mission.title,
              doneCondition: draft.doneCondition,
              expectedOutput: draft.doneCondition,
              orderIndex: existing.length,
              generatedBy: TaskGeneratedBy.user,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Taskを追加しました。')));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _generationError = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }
}

class _TaskActions extends StatelessWidget {
  const _TaskActions({
    required this.isGenerating,
    required this.onGenerate,
    required this.onManualAdd,
  });

  final bool isGenerating;
  final VoidCallback onGenerate;
  final VoidCallback onManualAdd;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      FilledButton.icon(
        onPressed: isGenerating ? null : onGenerate,
        icon: isGenerating
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome_outlined),
        label: Text(isGenerating ? '考えています' : 'Arcに提案してもらう'),
      ),
      OutlinedButton.icon(
        onPressed: isGenerating ? null : onManualAdd,
        icon: const Icon(Icons.add),
        label: const Text('自分で追加'),
      ),
    ],
  );
}

class _TaskSuggestionDialog extends StatelessWidget {
  const _TaskSuggestionDialog({required this.suggestions});
  final List<TaskSuggestion> suggestions;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('ArcからのTask提案'),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 460),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const Divider(height: 24),
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                suggestion.title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(suggestion.action),
              const SizedBox(height: 5),
              Text(
                '完了: ${suggestion.doneCondition}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('あとで'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: Text('${suggestions.length}件を追加'),
      ),
    ],
  );
}

class _ManualTaskDraft {
  const _ManualTaskDraft({
    required this.title,
    required this.action,
    required this.doneCondition,
  });
  final String title;
  final String action;
  final String doneCondition;
}

class _ManualTaskDialog extends StatefulWidget {
  const _ManualTaskDialog();

  @override
  State<_ManualTaskDialog> createState() => _ManualTaskDialogState();
}

class _ManualTaskDialogState extends State<_ManualTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _action = TextEditingController();
  final _doneCondition = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _action.dispose();
    _doneCondition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Taskを追加'),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QuestraFieldLabel(
                label: 'Task名',
                required: true,
                child: TextFormField(
                  controller: _title,
                  maxLength: 100,
                  decoration: const InputDecoration(hintText: '例: 候補日を3つ書き出す'),
                  validator: (value) => _required(value, 3),
                ),
              ),
              const SizedBox(height: 14),
              QuestraFieldLabel(
                label: '実行すること',
                required: true,
                child: TextFormField(
                  controller: _action,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: '具体的な行動を入力'),
                  validator: (value) => _required(value, 5),
                ),
              ),
              const SizedBox(height: 14),
              QuestraFieldLabel(
                label: '完了の目印',
                required: true,
                child: TextFormField(
                  controller: _doneCondition,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: '何ができたら完了かを入力'),
                  validator: (value) => _required(value, 5),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('キャンセル'),
      ),
      FilledButton(onPressed: _submit, child: const Text('追加')),
    ],
  );

  String? _required(String? value, int minimum) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '入力してください。';
    if (text.length < minimum) return '$minimum文字以上で入力してください。';
    return null;
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(
      _ManualTaskDraft(
        title: _title.text.trim(),
        action: _action.text.trim(),
        doneCondition: _doneCondition.text.trim(),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});
  final QuestraTask task;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(
          AppRoutes.taskDetail(task.questId, task.missionId, task.id),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                task.status == TaskStatus.completed
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TASK  ${task.status.label}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      task.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (task.doneCondition.isNotEmpty)
                      Text(
                        task.doneCondition,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    ),
  );
}
