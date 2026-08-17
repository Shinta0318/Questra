import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/questra_colors.dart';
import '../../widgets/questra_card.dart';
import '../mission/mission_model.dart';
import '../quest/quest_model.dart';
import '../task/task_controller.dart';
import '../task/task_model.dart';
import 'quest_journey_contract.dart';

class QuestJourneyWorkspace extends ConsumerStatefulWidget {
  const QuestJourneyWorkspace({
    required this.quest,
    required this.missions,
    required this.onCreateMission,
    required this.onAskArcForMission,
    this.initialMode = QuestJourneyMode.focus,
    this.focusMissionId,
    this.focusTaskId,
    super.key,
  });

  final Quest quest;
  final List<Mission> missions;
  final VoidCallback onCreateMission;
  final VoidCallback onAskArcForMission;
  final QuestJourneyMode initialMode;
  final String? focusMissionId;
  final String? focusTaskId;

  @override
  ConsumerState<QuestJourneyWorkspace> createState() =>
      _QuestJourneyWorkspaceState();
}

class _QuestJourneyWorkspaceState extends ConsumerState<QuestJourneyWorkspace> {
  late QuestJourneyMode _mode;
  final Set<String> _expandedMissionIds = {};
  bool _completedExpanded = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    final requested = widget.focusMissionId;
    if (requested != null) {
      _expandedMissionIds.add(requested);
    } else {
      final current = widget.missions
          .where((mission) => mission.status != MissionStatus.completed)
          .firstOrNull;
      if (current != null) _expandedMissionIds.add(current.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTasks = ref.watch(taskControllerProvider);
    final tasks = allTasks
        .where((task) => task.questId == widget.quest.id)
        .toList(growable: false);
    final progress = const QuestJourneyProgressService().calculate(
      widget.missions,
    );
    final focus = const QuestFocusSelectionService().select(
      tasks: tasks,
      missions: widget.missions,
    );

    return Semantics(
      container: true,
      label: 'Questの航路ワークスペース',
      child: QuestraCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WorkspaceHeader(quest: widget.quest, progress: progress),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<QuestJourneyMode>(
                segments: const [
                  ButtonSegment(
                    value: QuestJourneyMode.focus,
                    icon: Icon(Icons.near_me_outlined),
                    label: Text('次の一歩'),
                  ),
                  ButtonSegment(
                    value: QuestJourneyMode.plan,
                    icon: Icon(Icons.route_outlined),
                    label: Text('航路'),
                  ),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    setState(() => _mode = value.single),
              ),
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _mode == QuestJourneyMode.focus
                  ? _FocusView(
                      key: const ValueKey('focus'),
                      tasks: focus,
                      onToggle: _toggleTask,
                      onOpen: _openTask,
                      onRemoveToday: _removeFromToday,
                    )
                  : _PlanView(
                      key: const ValueKey('plan'),
                      quest: widget.quest,
                      missions: widget.missions,
                      tasks: tasks,
                      expandedMissionIds: _expandedMissionIds,
                      completedExpanded: _completedExpanded,
                      focusTaskId: widget.focusTaskId,
                      onMissionToggle: (id) => setState(() {
                        _expandedMissionIds.contains(id)
                            ? _expandedMissionIds.remove(id)
                            : _expandedMissionIds.add(id);
                      }),
                      onCompletedToggle: () => setState(
                        () => _completedExpanded = !_completedExpanded,
                      ),
                      onToggleTask: _toggleTask,
                      onOpenTask: _openTask,
                      onAddTask: _addTask,
                      onReorder: _reorderTasks,
                      onRemoveToday: _removeFromToday,
                      onConsultArc: _consultArc,
                      onOpenSupport: _openSupport,
                      onCreateMission: widget.onCreateMission,
                      onAskArcForMission: widget.onAskArcForMission,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTask(QuestraTask task) async {
    final controller = ref.read(taskControllerProvider.notifier);
    final ok = task.status == TaskStatus.completed
        ? await controller.reopen(task.id)
        : await controller.completeFromWorkspace(task.id);
    if (!mounted || !ok) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            task.status == TaskStatus.completed
                ? 'Taskを未完了へ戻しました。'
                : 'Taskを完了しました。',
          ),
          action: task.status == TaskStatus.completed
              ? null
              : SnackBarAction(
                  label: '元に戻す',
                  onPressed: () => controller.reopen(task.id),
                ),
        ),
      );
  }

  void _openTask(QuestraTask task) =>
      context.push(AppRoutes.taskDetail(task.questId, task.missionId, task.id));

  Future<void> _removeFromToday(QuestraTask task) async {
    final ok = await ref
        .read(taskControllerProvider.notifier)
        .updateTask(task.copyWith(clearScheduledDate: true));
    if (mounted && ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('今日のFocusから外しました。')));
    }
  }

  Future<void> _addTask(Mission mission) async {
    final title = await showDialog<String>(
      context: context,
      builder: (context) => const _AddTaskDialog(),
    );
    if (title == null || title.trim().isEmpty) return;
    final missionTasks = ref
        .read(taskControllerProvider.notifier)
        .forMission(mission.id);
    await ref
        .read(taskControllerProvider.notifier)
        .addTask(
          QuestraTask(
            questId: widget.quest.id,
            questTitle: widget.quest.title,
            missionId: mission.id,
            missionTitle: mission.title,
            title: title.trim(),
            action: title.trim(),
            doneCondition: '$titleを実行し、結果を確認する',
            orderIndex: missionTasks.length,
            origin: TaskOrigin.user,
          ),
        );
  }

  Future<void> _reorderTasks(Mission mission, List<QuestraTask> ordered) async {
    final ok = await ref
        .read(taskControllerProvider.notifier)
        .reorderMissionTasks(mission.id, ordered);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Taskの順番を保存できませんでした。もう一度お試しください。')),
    );
  }

  void _consultArc(Mission mission) => context.push(
    AppRoutes.arcForMission(
      questId: widget.quest.id,
      missionId: mission.id,
      prompt: '「${mission.title}」の進め方を一緒に見直したい',
      returnTo: '/quest/${widget.quest.id}?mode=plan&mission=${mission.id}',
    ),
  );

  void _openSupport(Mission mission) =>
      context.push(AppRoutes.missionSupport(widget.quest.id, mission.id));
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({required this.quest, required this.progress});
  final Quest quest;
  final QuestJourneyProgress progress;

  @override
  Widget build(BuildContext context) {
    final target = quest.targetDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '航路を進める',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${progress.percent}%',
              style: const TextStyle(
                color: QuestraColors.gold,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          target == null
              ? progress.label
              : '${progress.label}  ·  目標 ${target.year}/${target.month.toString().padLeft(2, '0')}',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress.weightedProgress,
            minHeight: 8,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation(QuestraColors.gold),
            semanticsLabel: 'Questの成果進捗 ${progress.percent}パーセント',
          ),
        ),
      ],
    );
  }
}

class _FocusView extends StatelessWidget {
  const _FocusView({
    required this.tasks,
    required this.onToggle,
    required this.onOpen,
    required this.onRemoveToday,
    super.key,
  });
  final List<QuestraTask> tasks;
  final ValueChanged<QuestraTask> onToggle;
  final ValueChanged<QuestraTask> onOpen;
  final ValueChanged<QuestraTask> onRemoveToday;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const _EmptyFocus();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '今ここから',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '迷わないよう、次の行動だけを表示しています。',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 12),
        for (final task in tasks) ...[
          _TaskRow(
            task: task,
            onToggle: () => onToggle(task),
            onOpen: () => onOpen(task),
            onRemoveToday: () => onRemoveToday(task),
          ),
          if (task != tasks.last) const Divider(color: Colors.white12),
        ],
      ],
    );
  }
}

class _PlanView extends StatelessWidget {
  const _PlanView({
    required this.quest,
    required this.missions,
    required this.tasks,
    required this.expandedMissionIds,
    required this.completedExpanded,
    required this.focusTaskId,
    required this.onMissionToggle,
    required this.onCompletedToggle,
    required this.onToggleTask,
    required this.onOpenTask,
    required this.onAddTask,
    required this.onReorder,
    required this.onRemoveToday,
    required this.onConsultArc,
    required this.onOpenSupport,
    required this.onCreateMission,
    required this.onAskArcForMission,
    super.key,
  });
  final Quest quest;
  final List<Mission> missions;
  final List<QuestraTask> tasks;
  final Set<String> expandedMissionIds;
  final bool completedExpanded;
  final String? focusTaskId;
  final ValueChanged<String> onMissionToggle;
  final VoidCallback onCompletedToggle;
  final ValueChanged<QuestraTask> onToggleTask;
  final ValueChanged<QuestraTask> onOpenTask;
  final ValueChanged<Mission> onAddTask;
  final void Function(Mission, List<QuestraTask>) onReorder;
  final ValueChanged<QuestraTask> onRemoveToday;
  final ValueChanged<Mission> onConsultArc;
  final ValueChanged<Mission> onOpenSupport;
  final VoidCallback onCreateMission;
  final VoidCallback onAskArcForMission;

  @override
  Widget build(BuildContext context) {
    final open = missions
        .where((mission) => mission.status != MissionStatus.completed)
        .toList(growable: false);
    final completed = missions
        .where((mission) => mission.status == MissionStatus.completed)
        .toList(growable: false);
    if (open.isEmpty && completed.isEmpty) {
      return _EmptyPlan(
        onCreateMission: onCreateMission,
        onAskArcForMission: onAskArcForMission,
      );
    }
    return Column(
      children: [
        for (final mission in open)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MissionAccordion(
              mission: mission,
              tasks: tasks
                  .where((task) => task.missionId == mission.id)
                  .toList(growable: false),
              expanded: expandedMissionIds.contains(mission.id),
              focusTaskId: focusTaskId,
              onToggle: () => onMissionToggle(mission.id),
              onToggleTask: onToggleTask,
              onOpenTask: onOpenTask,
              onAddTask: () => onAddTask(mission),
              onReorder: (ordered) => onReorder(mission, ordered),
              onRemoveToday: onRemoveToday,
              onConsultArc: () => onConsultArc(mission),
              onOpenSupport: mission.enterpriseSupportHints.isEmpty
                  ? null
                  : () => onOpenSupport(mission),
            ),
          ),
        if (completed.isNotEmpty)
          _CompletedMissionGroup(
            missions: completed,
            expanded: completedExpanded,
            onToggle: onCompletedToggle,
          ),
      ],
    );
  }
}

class _EmptyPlan extends StatelessWidget {
  const _EmptyPlan({
    required this.onCreateMission,
    required this.onAskArcForMission,
  });
  final VoidCallback onCreateMission;
  final VoidCallback onAskArcForMission;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '航路はまだ白紙です',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Arcと中間成果を考えるか、自分で最初のMissionを追加できます。',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: onAskArcForMission,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Arcと航路を描く'),
            ),
            OutlinedButton.icon(
              onPressed: onCreateMission,
              icon: const Icon(Icons.add),
              label: const Text('Missionを追加'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _MissionAccordion extends StatefulWidget {
  const _MissionAccordion({
    required this.mission,
    required this.tasks,
    required this.expanded,
    required this.focusTaskId,
    required this.onToggle,
    required this.onToggleTask,
    required this.onOpenTask,
    required this.onAddTask,
    required this.onReorder,
    required this.onRemoveToday,
    required this.onConsultArc,
    this.onOpenSupport,
  });
  final Mission mission;
  final List<QuestraTask> tasks;
  final bool expanded;
  final String? focusTaskId;
  final VoidCallback onToggle;
  final ValueChanged<QuestraTask> onToggleTask;
  final ValueChanged<QuestraTask> onOpenTask;
  final VoidCallback onAddTask;
  final ValueChanged<List<QuestraTask>> onReorder;
  final ValueChanged<QuestraTask> onRemoveToday;
  final VoidCallback onConsultArc;
  final VoidCallback? onOpenSupport;

  @override
  State<_MissionAccordion> createState() => _MissionAccordionState();
}

class _MissionAccordionState extends State<_MissionAccordion> {
  bool _showCompleted = false;

  @override
  Widget build(BuildContext context) {
    final sorted = widget.tasks.toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final active = sorted
        .where((task) => task.status != TaskStatus.completed)
        .toList(growable: false);
    final completed = sorted
        .where((task) => task.status == TaskStatus.completed)
        .toList(growable: false);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Semantics(
            button: true,
            expanded: widget.expanded,
            label: 'Mission ${widget.mission.title}',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: widget.onToggle,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      widget.expanded ? Icons.expand_less : Icons.expand_more,
                      color: QuestraColors.skyBlue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.mission.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${completed.length}/${sorted.length} Task',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.mission.isOptional)
                      const _SmallBadge(label: '任意'),
                  ],
                ),
              ),
            ),
          ),
          if (widget.expanded) ...[
            const Divider(height: 1, color: Colors.white12),
            if (active.isEmpty && completed.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Taskはまだありません。次の一歩を追加しましょう。',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: active.length,
                onReorderItem: (oldIndex, newIndex) {
                  final reordered = active.toList();
                  final moved = reordered.removeAt(oldIndex);
                  reordered.insert(newIndex, moved);
                  widget.onReorder([...reordered, ...completed]);
                },
                itemBuilder: (context, index) {
                  final task = active[index];
                  return Container(
                    key: ValueKey(task.id),
                    color: task.id == widget.focusTaskId
                        ? QuestraColors.cosmicBlue.withValues(alpha: 0.12)
                        : Colors.transparent,
                    child: _TaskRow(
                      task: task,
                      onToggle: () => widget.onToggleTask(task),
                      onOpen: () => widget.onOpenTask(task),
                      onRemoveToday: () => widget.onRemoveToday(task),
                      trailing: ReorderableDragStartListener(
                        index: index,
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(Icons.drag_handle, color: Colors.white54),
                        ),
                      ),
                    ),
                  );
                },
              ),
            if (completed.isNotEmpty)
              TextButton.icon(
                onPressed: () =>
                    setState(() => _showCompleted = !_showCompleted),
                icon: Icon(
                  _showCompleted ? Icons.expand_less : Icons.expand_more,
                ),
                label: Text('完了したTask ${completed.length}件'),
              ),
            if (_showCompleted)
              for (final task in completed)
                _TaskRow(
                  task: task,
                  onToggle: () => widget.onToggleTask(task),
                  onOpen: () => widget.onOpenTask(task),
                  onRemoveToday: () => widget.onRemoveToday(task),
                ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.onAddTask,
                    icon: const Icon(Icons.add),
                    label: const Text('Taskを追加'),
                  ),
                  TextButton.icon(
                    onPressed: widget.onConsultArc,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Arcに相談'),
                  ),
                  if (widget.onOpenSupport case final callback?)
                    TextButton.icon(
                      onPressed: callback,
                      icon: const Icon(Icons.handshake_outlined),
                      label: const Text('支援を見る'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.onToggle,
    required this.onOpen,
    required this.onRemoveToday,
    this.trailing,
  });
  final QuestraTask task;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final VoidCallback onRemoveToday;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final completed = task.status == TaskStatus.completed;
    return Semantics(
      container: true,
      label: 'Task ${task.title}、${task.status.label}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              tooltip: completed ? '未完了へ戻す' : '完了にする',
              onPressed: onToggle,
              icon: Icon(
                completed ? Icons.check_circle : Icons.circle_outlined,
                color: completed ? QuestraColors.gold : Colors.white70,
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: completed ? Colors.white54 : Colors.white,
                          decoration: completed
                              ? TextDecoration.lineThrough
                              : null,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (task.missionTitle.isNotEmpty)
                            Text(
                              task.missionTitle,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          if (task.estimatedEffortMinutes case final minutes?)
                            _SmallBadge(label: '約$minutes分'),
                          if (task.origin != TaskOrigin.user)
                            _SmallBadge(label: task.origin.label),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            trailing ??
                PopupMenuButton<String>(
                  tooltip: 'Taskのその他の操作',
                  onSelected: (value) {
                    if (value == 'today_remove') onRemoveToday();
                    if (value == 'detail') onOpen();
                  },
                  itemBuilder: (context) => [
                    if (task.scheduledDate != null)
                      const PopupMenuItem(
                        value: 'today_remove',
                        child: Text('今日から外す'),
                      ),
                    const PopupMenuItem(value: 'detail', child: Text('詳細を開く')),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}

class _CompletedMissionGroup extends StatelessWidget {
  const _CompletedMissionGroup({
    required this.missions,
    required this.expanded,
    required this.onToggle,
  });
  final List<Mission> missions;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: onToggle,
        leading: const Icon(Icons.verified_outlined, color: QuestraColors.gold),
        title: Text(
          '完了したMission ${missions.length}件',
          style: const TextStyle(color: Colors.white),
        ),
        trailing: Icon(
          expanded ? Icons.expand_less : Icons.expand_more,
          color: Colors.white70,
        ),
      ),
      if (expanded)
        for (final mission in missions)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 8),
            leading: const Icon(Icons.check, color: QuestraColors.gold),
            title: Text(
              mission.title,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
    ],
  );
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _EmptyFocus extends StatelessWidget {
  const _EmptyFocus();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Icon(Icons.auto_awesome, color: QuestraColors.gold),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            '今すぐ進めるTaskはありません。航路を開いて次の一歩を整えましょう。',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ],
    ),
  );
}

class _AddTaskDialog extends StatefulWidget {
  const _AddTaskDialog();

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('次のTaskを追加'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 120,
      textInputAction: TextInputAction.done,
      onSubmitted: (value) => _submit(),
      decoration: const InputDecoration(
        labelText: '実行すること',
        hintText: '例：航空券の候補を3つ比較する',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('キャンセル'),
      ),
      FilledButton(onPressed: _submit, child: const Text('追加')),
    ],
  );

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.pop(context, value);
  }
}
