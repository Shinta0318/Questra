import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/questra_surface_palette.dart';
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
  bool _correctionBusy = false;
  bool _requestBusy = false;
  List<DataRightsRequest> _requests = const [];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadRequests);
  }

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
          Text(
            'エクスポートと削除は本人の操作だけで実行され、履歴には内容ではなく操作結果だけが残ります。',
            style: TextStyle(color: QuestraSurfacePalette.dark.muted),
          ),
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
          _CorrectionRequestCard(
            requests: _requests,
            busy: _correctionBusy,
            onRequest: _requestCorrection,
          ),
          const SizedBox(height: AppSpacing.xl),
          _AccountDeletionCard(
            requests: _requests,
            busy: _requestBusy,
            onRequest: _requestAccountDeletion,
            onCancel: _cancelRequest,
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
          Text(
            '削除前に、残るTrailと削除されるArc Memoryの件数を確認できます。',
            style: TextStyle(color: QuestraSurfacePalette.dark.muted),
          ),
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
      final shouldCopy = await showDialog<bool>(
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
              onPressed: () => Navigator.pop(context, false),
              child: const Text('閉じる'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('JSONをコピー'),
            ),
          ],
        ),
      );
      if (shouldCopy == true && mounted) {
        await Clipboard.setData(
          ClipboardData(text: jsonEncode(manifest.payload)),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('データをコピーしました。共有端末では貼り付け後にクリップボードを消してください。'),
            ),
          );
        }
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _requestCorrection() async {
    final controller = TextEditingController();
    var targetType = 'profile';
    var requestedChange = '';
    final draft = await showDialog<_CorrectionDraft>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('訂正を依頼'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('訂正する情報'),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<String>(
                initialValue: targetType,
                items: const [
                  DropdownMenuItem(value: 'profile', child: Text('プロフィール')),
                  DropdownMenuItem(
                    value: 'arc_memory',
                    child: Text('Arc Memory'),
                  ),
                  DropdownMenuItem(
                    value: 'quest_dna',
                    child: Text('Quest DNA'),
                  ),
                  DropdownMenuItem(value: 'tag', child: Text('Tag')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => targetType = value);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('正しい内容'),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: controller,
                minLines: 3,
                maxLines: 6,
                maxLength: 500,
                onChanged: (value) {
                  setDialogState(() => requestedChange = value);
                },
                decoration: const InputDecoration(
                  hintText: '誤っている箇所と、正しい内容を書いてください。',
                  helperText: '5文字以上で具体的に入力してください。',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('戻る'),
            ),
            FilledButton(
              onPressed: requestedChange.trim().length < 5
                  ? null
                  : () => Navigator.pop(
                      context,
                      _CorrectionDraft(targetType, requestedChange.trim()),
                    ),
              child: const Text('依頼する'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (draft == null || !mounted) return;
    setState(() => _correctionBusy = true);
    try {
      await ref
          .read(dataRightsRepositoryProvider)
          .requestCorrection(
            targetType: draft.targetType,
            requestedChange: draft.requestedChange,
          );
      await _loadRequests();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('訂正依頼を受け付けました。')));
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _correctionBusy = false);
    }
  }

  Future<void> _loadRequests() async {
    try {
      final requests = await ref
          .read(dataRightsRepositoryProvider)
          .listRequests();
      if (mounted) setState(() => _requests = requests);
    } catch (_) {
      // The local preview intentionally keeps remote-only controls unavailable.
    }
  }

  Future<void> _requestAccountDeletion() async {
    final passwordController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('本人確認'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '現在のパスワード',
            helperText: '削除予約には直近の再認証が必要です。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('戻る'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, passwordController.text),
            child: const Text('72時間後に削除予約'),
          ),
        ],
      ),
    );
    passwordController.dispose();
    if (password == null || password.isEmpty || !mounted) return;
    setState(() => _requestBusy = true);
    try {
      await ref
          .read(dataRightsRepositoryProvider)
          .requestAccountDeletion(password: password);
      await _loadRequests();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _requestBusy = false);
    }
  }

  Future<void> _cancelRequest(DataRightsRequest request) async {
    setState(() => _requestBusy = true);
    try {
      await ref.read(dataRightsRepositoryProvider).cancelRequest(request.id);
      await _loadRequests();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _requestBusy = false);
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

class _CorrectionDraft {
  const _CorrectionDraft(this.targetType, this.requestedChange);

  final String targetType;
  final String requestedChange;
}

class _CorrectionRequestCard extends StatelessWidget {
  const _CorrectionRequestCard({
    required this.requests,
    required this.busy,
    required this.onRequest,
  });

  final List<DataRightsRequest> requests;
  final bool busy;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final latest = requests
        .where((request) => request.type == 'correction')
        .firstOrNull;
    return QuestraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_note_outlined),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '情報を訂正する',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text('プロフィール、Arc Memory、Quest DNA、Tagの誤りを本人から訂正依頼できます。'),
          if (latest != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('最新状態: ${latest.status}'),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onRequest,
              icon: const Icon(Icons.edit_note_outlined),
              label: Text(busy ? '送信中' : '訂正を依頼'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountDeletionCard extends StatelessWidget {
  const _AccountDeletionCard({
    required this.requests,
    required this.busy,
    required this.onRequest,
    required this.onCancel,
  });

  final List<DataRightsRequest> requests;
  final bool busy;
  final VoidCallback onRequest;
  final ValueChanged<DataRightsRequest> onCancel;

  @override
  Widget build(BuildContext context) {
    final deletionRequests = requests
        .where((request) => request.type == 'account_deletion')
        .toList(growable: false);
    final cancellable = deletionRequests
        .where((request) => request.canCancel)
        .firstOrNull;
    return QuestraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_remove_outlined),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'アカウント削除',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text('本人確認後に削除を予約します。予約後72時間は取り消せます。'),
          if (deletionRequests.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              cancellable != null
                  ? '削除予約中（取消可能）'
                  : '最新状態: ${deletionRequests.first.status}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: cancellable == null
                ? OutlinedButton.icon(
                    onPressed: busy ? null : onRequest,
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text(busy ? '確認中' : '削除を予約'),
                  )
                : FilledButton.tonalIcon(
                    onPressed: busy ? null : () => onCancel(cancellable),
                    icon: const Icon(Icons.undo),
                    label: const Text('削除予約を取り消す'),
                  ),
          ),
        ],
      ),
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
