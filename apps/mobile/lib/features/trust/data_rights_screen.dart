import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/questra_card.dart';
import '../task/task_controller.dart';
import '../task/task_model.dart';
import 'data_rights_repository.dart';

class DataRightsScreen extends ConsumerStatefulWidget {
  const DataRightsScreen({super.key});

  @override
  ConsumerState<DataRightsScreen> createState() => _DataRightsScreenState();
}

class _DataRightsScreenState extends ConsumerState<DataRightsScreen> {
  String? _busyTaskId;
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      appBar: AppBar(title: const Text('データ管理')),
      body: QuestraResponsiveListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text(
            '自分の旅路を確認・管理',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text('エクスポートと削除は本人の操作だけで実行され、履歴には内容ではなく操作結果だけが残ります。'),
          const SizedBox(height: AppSpacing.lg),
          QuestraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.file_download_outlined),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'データを確認する',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Profile、Quest、Mission、Task、Trail、Arc MemoryをJSON形式で準備します。',
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _exporting ? null : _export,
                    icon: const Icon(Icons.file_download_outlined),
                    label: Text(_exporting ? '準備中' : '作成'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Taskを削除',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text('削除前に、残るTrailと削除されるArc Memoryの件数を確認できます。'),
          const SizedBox(height: AppSpacing.md),
          if (tasks.isEmpty)
            const QuestraCard(child: Text('削除できるTaskはありません。'))
          else
            for (final task in tasks)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _TaskDeletionTile(
                  task: task,
                  busy: _busyTaskId == task.id,
                  onPreview: () => _previewDeletion(task),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final manifest = await ref
          .read(dataRightsRepositoryProvider)
          .exportMyData();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('データを準備しました'),
          content: Text(
            manifest.counts.entries
                .map((entry) => '${entry.key}: ${entry.value}件')
                .join('\n'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _previewDeletion(QuestraTask task) async {
    setState(() => _busyTaskId = task.id);
    try {
      final repository = ref.read(dataRightsRepositoryProvider);
      final preview = await repository.previewTaskDeletion(task.id);
      if (!mounted) return;
      setState(() => _busyTaskId = null);
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('「${preview.taskTitle}」を削除しますか？'),
          content: Text(
            'Trail ${preview.trailCount}件は記録として残り、Taskとの紐づきだけが外れます。'
            '\nArc Memory ${preview.memoryCount}件は削除されます。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('やめる'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('削除する'),
            ),
          ],
        ),
      );
      if (accepted != true) return;
      await repository.deleteTask(preview);
      await ref.read(taskControllerProvider.notifier).reload();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Taskを削除しました。')));
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busyTaskId = null);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
    );
  }
}

class _TaskDeletionTile extends StatelessWidget {
  const _TaskDeletionTile({
    required this.task,
    required this.busy,
    required this.onPreview,
  });

  final QuestraTask task;
  final bool busy;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return QuestraCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(task.title),
        subtitle: Text('${task.questTitle} / ${task.missionTitle}'),
        trailing: IconButton(
          onPressed: busy ? null : onPreview,
          tooltip: '削除の影響を確認',
          icon: busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_outline),
        ),
      ),
    );
  }
}
