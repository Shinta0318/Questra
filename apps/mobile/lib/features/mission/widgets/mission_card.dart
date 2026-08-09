import 'package:flutter/material.dart';

import '../../../core/theme/questra_colors.dart';
import '../../../widgets/menu/questra_action_menu.dart';
import '../../../widgets/questra_card.dart';
import '../../task/task_model.dart';
import '../mission_model.dart';
import 'mission_card_presentation.dart';

enum MissionCardMenuAction {
  consultArc,
  viewSupport,
  edit,
  reviewTasks,
  regenerate,
  changeDueDate,
  reorder,
  toggleOptional,
  archive,
  delete,
}

class MissionCard extends StatefulWidget {
  const MissionCard({
    required this.mission,
    required this.tasks,
    required this.completedMissionIds,
    required this.onPrimaryPressed,
    required this.onMenuSelected,
    this.onViewed,
    this.onExpandedChanged,
    this.onMoreMenuOpened,
    this.parentMissionTitle,
    this.menuActions = MissionCardMenuAction.values,
    super.key,
  });

  final Mission mission;
  final List<QuestraTask> tasks;
  final Set<String> completedMissionIds;
  final String? parentMissionTitle;
  final ValueChanged<MissionCardPresentation> onPrimaryPressed;
  final ValueChanged<MissionCardMenuAction> onMenuSelected;
  final VoidCallback? onViewed;
  final ValueChanged<bool>? onExpandedChanged;
  final VoidCallback? onMoreMenuOpened;
  final List<MissionCardMenuAction> menuActions;

  @override
  State<MissionCard> createState() => _MissionCardState();
}

class _MissionCardState extends State<MissionCard> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.onViewed?.call(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = MissionCardPresentation.resolve(
      mission: widget.mission,
      tasks: widget.tasks,
      completedMissionIds: widget.completedMissionIds,
    );
    final success = widget.mission.successCondition.isNotEmpty
        ? widget.mission.successCondition
        : widget.mission.doneCondition.isNotEmpty
        ? widget.mission.doneCondition
        : widget.mission.description;
    final tasks = widget.tasks.toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    return Semantics(
      container: true,
      label: 'Mission ${widget.mission.title}、${state.statusLabel}',
      child: QuestraCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _MissionLabel(),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.totalTasks == 0
                        ? state.statusLabel
                        : '${state.completedTasks} / ${state.totalTasks} Task',
                    style: const TextStyle(
                      color: QuestraColors.slate,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (widget.menuActions.isNotEmpty)
                  QuestraPopupMenu<MissionCardMenuAction>(
                    tooltip: 'Missionのその他の操作',
                    onOpened: widget.onMoreMenuOpened,
                    onSelected: widget.onMenuSelected,
                    items: [
                      if (widget.menuActions.contains(
                        MissionCardMenuAction.consultArc,
                      ))
                        const QuestraMenuItem(
                          value: MissionCardMenuAction.consultArc,
                          label: 'Arcに相談',
                          icon: Icons.auto_awesome_outlined,
                        ),
                      if (widget.menuActions.contains(
                        MissionCardMenuAction.viewSupport,
                      ))
                        const QuestraMenuItem(
                          value: MissionCardMenuAction.viewSupport,
                          label: '実行サポート',
                          icon: Icons.travel_explore_outlined,
                        ),
                      if (widget.menuActions.contains(
                        MissionCardMenuAction.edit,
                      ))
                        const QuestraMenuItem(
                          value: MissionCardMenuAction.edit,
                          label: 'Missionを編集',
                          icon: Icons.edit_outlined,
                        ),
                      if (widget.menuActions.contains(
                        MissionCardMenuAction.reviewTasks,
                      ))
                        const QuestraMenuItem(
                          value: MissionCardMenuAction.reviewTasks,
                          label: 'Taskを見直す',
                          icon: Icons.checklist_outlined,
                        ),
                      if (widget.menuActions.contains(
                        MissionCardMenuAction.regenerate,
                      ))
                        const QuestraMenuItem(
                          value: MissionCardMenuAction.regenerate,
                          label: 'Missionを再生成',
                          icon: Icons.auto_fix_high_outlined,
                        ),
                      if (widget.menuActions.contains(
                        MissionCardMenuAction.changeDueDate,
                      ))
                        const QuestraMenuItem(
                          value: MissionCardMenuAction.changeDueDate,
                          label: '期限を変更',
                          icon: Icons.event_outlined,
                        ),
                      if (widget.menuActions.contains(
                        MissionCardMenuAction.reorder,
                      ))
                        const QuestraMenuItem(
                          value: MissionCardMenuAction.reorder,
                          label: '順番を変更',
                          icon: Icons.swap_vert,
                        ),
                      if (widget.menuActions.contains(
                        MissionCardMenuAction.toggleOptional,
                      ))
                        QuestraMenuItem(
                          value: MissionCardMenuAction.toggleOptional,
                          label: widget.mission.isOptional ? '必須に戻す' : '任意にする',
                          icon: Icons.low_priority,
                        ),
                      if (widget.menuActions.contains(
                        MissionCardMenuAction.archive,
                      ))
                        const QuestraMenuItem(
                          value: MissionCardMenuAction.archive,
                          label: 'アーカイブ',
                          icon: Icons.archive_outlined,
                        ),
                      if (widget.menuActions.contains(
                        MissionCardMenuAction.delete,
                      ))
                        const QuestraMenuItem(
                          value: MissionCardMenuAction.delete,
                          label: 'Missionを削除',
                          icon: Icons.delete_outline,
                          destructive: true,
                        ),
                    ],
                  ),
              ],
            ),
            if (widget.parentMissionTitle case final title?) ...[
              Text(
                '$title の下位Mission',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: QuestraColors.slate,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              widget.mission.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            if (success.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                success,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: QuestraColors.slate),
              ),
            ],
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: state.progress,
                minHeight: 7,
                backgroundColor: QuestraColors.cloud,
                valueColor: const AlwaysStoppedAnimation(QuestraColors.gold),
                semanticsLabel: 'Missionの進捗',
              ),
            ),
            const SizedBox(height: 10),
            if (state.nextTask case final task?)
              _NextTask(task: task)
            else if (tasks.isEmpty)
              const Text(
                'Taskはまだありません。Missionを開いて次の行動を決めましょう。',
                style: TextStyle(color: QuestraColors.slate),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MetadataChip(label: '優先度 ${widget.mission.priority.label}'),
                if (widget.mission.targetDate case final date?)
                  _MetadataChip(
                    label:
                        '期限 ${date.year}/${date.month.toString().padLeft(2, '0')}',
                  ),
                if (widget.mission.dependencyIds.isNotEmpty)
                  _MetadataChip(
                    label: '前提 ${widget.mission.dependencyIds.length}件',
                  )
                else if (widget.mission.isOptional)
                  const _MetadataChip(label: '任意'),
              ],
            ),
            if (tasks.length > 1) ...[
              TextButton.icon(
                onPressed: () {
                  setState(() => _expanded = !_expanded);
                  widget.onExpandedChanged?.call(_expanded);
                },
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                label: Text(_expanded ? 'Task一覧を閉じる' : '残りのTaskを見る'),
              ),
              if (_expanded)
                for (final task in tasks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          task.status == TaskStatus.completed
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(task.title)),
                      ],
                    ),
                  ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => widget.onPrimaryPressed(state),
                icon: Icon(_primaryIcon(state.primaryAction)),
                label: Text(state.primaryLabel),
                style: FilledButton.styleFrom(minimumSize: const Size(44, 48)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _primaryIcon(MissionCardPrimaryAction action) => switch (action) {
  MissionCardPrimaryAction.startNextTask => Icons.play_arrow,
  MissionCardPrimaryAction.resumeTask => Icons.play_circle_outline,
  MissionCardPrimaryAction.reviewOutcome => Icons.fact_check_outlined,
  MissionCardPrimaryAction.viewCompleted => Icons.verified_outlined,
  MissionCardPrimaryAction.viewDependencies => Icons.account_tree_outlined,
  MissionCardPrimaryAction.viewTasks => Icons.checklist_outlined,
};

class _MissionLabel extends StatelessWidget {
  const _MissionLabel();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: QuestraColors.cosmicBlue.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Text(
      'MISSION',
      style: TextStyle(
        color: QuestraColors.cosmicBlue,
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _NextTask extends StatelessWidget {
  const _NextTask({required this.task});
  final QuestraTask task;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: QuestraColors.cloud.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '次のTask',
          style: TextStyle(
            color: QuestraColors.slate,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: QuestraColors.white.withValues(alpha: 0.72),
      border: Border.all(color: QuestraColors.slate.withValues(alpha: 0.18)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}
