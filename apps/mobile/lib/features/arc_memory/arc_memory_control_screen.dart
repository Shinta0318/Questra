import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../auth/auth_controller.dart';
import '../trust/consent_controller.dart';
import '../trust/consent_purpose_registry_service.dart';
import 'arc_memory_model.dart';
import 'arc_memory_providers.dart';

class ArcMemoryControlScreen extends ConsumerWidget {
  const ArcMemoryControlScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decisions = ref.watch(consentControllerProvider).value ?? const {};
    final enabled =
        decisions[ConsentPurpose.arcPersonalization]?.isGranted == true;
    final memories = ref.watch(controllableArcMemoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      appBar: AppBar(title: const Text('Arc Memory')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Arcが覚えていること',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              '旅路に使う記憶を、自分で確認・訂正・削除できます。OFFにすると新しい記憶の保存とArcからの参照を止めます。',
              style: TextStyle(color: AppColors.parchment, height: 1.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ConsentCard(
              enabled: enabled,
              busy: ref.watch(consentControllerProvider).isLoading,
              onChanged: (value) async {
                await ref
                    .read(consentControllerProvider.notifier)
                    .setConsent(ConsentPurpose.arcPersonalization, value);
                ref.invalidate(visibleArcMemoriesProvider);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            memories.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _MessageCard(
                message: '記憶を読み込めませんでした。時間をおいて再試行してください。',
                actionLabel: '再試行',
                onAction: () => ref.invalidate(controllableArcMemoriesProvider),
              ),
              data: (items) => items.isEmpty
                  ? const _MessageCard(message: '保存されているArc Memoryはありません。')
                  : Column(
                      children: [
                        for (final memory in items) ...[
                          _MemoryCard(
                            memory: memory,
                            onEdit: () => _editMemory(context, ref, memory),
                            onDelete: () => _deleteMemory(context, ref, memory),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        OutlinedButton.icon(
                          onPressed: () =>
                              _deleteAll(context, ref, items.length),
                          icon: const Icon(Icons.delete_sweep_outlined),
                          label: const Text('すべての記憶を削除'),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editMemory(
    BuildContext context,
    WidgetRef ref,
    ArcMemory memory,
  ) async {
    final title = TextEditingController(text: memory.title);
    final content = TextEditingController(text: memory.content);
    final result = await showDialog<ArcMemory>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('記憶を訂正'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                maxLength: 80,
                decoration: const InputDecoration(labelText: '見出し'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: content,
                minLines: 3,
                maxLines: 6,
                maxLength: 500,
                decoration: const InputDecoration(labelText: '覚えている内容'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isEmpty || content.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(
                dialogContext,
                memory.copyWith(
                  title: title.text.trim(),
                  content: content.text.trim(),
                ),
              );
            },
            child: const Text('更新'),
          ),
        ],
      ),
    );
    title.dispose();
    content.dispose();
    if (result == null || !context.mounted) return;
    try {
      await ref.read(arcMemoryRepositoryProvider).update(result);
      if (!context.mounted) return;
      ref.invalidate(controllableArcMemoriesProvider);
      ref.invalidate(visibleArcMemoriesProvider);
      _notice(context, '記憶を更新しました。');
    } catch (_) {
      if (!context.mounted) return;
      _notice(context, '記憶を更新できませんでした。');
    }
  }

  Future<void> _deleteMemory(
    BuildContext context,
    WidgetRef ref,
    ArcMemory memory,
  ) async {
    final confirmed = await _confirm(
      context,
      title: 'この記憶を削除しますか？',
      message: '削除した記憶はArcの提案に使われなくなります。',
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref
          .read(arcMemoryRepositoryProvider)
          .deleteById(memory.userId, memory.id);
      if (!context.mounted) return;
      ref.invalidate(controllableArcMemoriesProvider);
      ref.invalidate(visibleArcMemoriesProvider);
      _notice(context, '記憶を削除しました。');
    } catch (_) {
      if (!context.mounted) return;
      _notice(context, '記憶を削除できませんでした。');
    }
  }

  Future<void> _deleteAll(
    BuildContext context,
    WidgetRef ref,
    int count,
  ) async {
    final profile = ref.read(authControllerProvider).profile;
    if (profile == null) return;
    final confirmed = await _confirm(
      context,
      title: 'すべての記憶を削除しますか？',
      message: '$count件のArc Memoryを削除します。この操作は元に戻せません。',
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(arcMemoryRepositoryProvider).deleteAllForUser(profile.id);
      if (!context.mounted) return;
      ref.invalidate(controllableArcMemoriesProvider);
      ref.invalidate(visibleArcMemoriesProvider);
      _notice(context, 'すべての記憶を削除しました。');
    } catch (_) {
      if (!context.mounted) return;
      _notice(context, '記憶を削除できませんでした。');
    }
  }
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({
    required this.enabled,
    required this.busy,
    required this.onChanged,
  });

  final bool enabled;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.midnightNavy,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        Icon(
          enabled ? Icons.memory_outlined : Icons.visibility_off_outlined,
          color: enabled ? AppColors.gold : AppColors.parchment,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Arc Memoryを旅路に使う',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                enabled ? '保存と関連する記憶の参照が有効です。' : '保存と参照を停止しています。',
                style: const TextStyle(color: AppColors.parchment),
              ),
            ],
          ),
        ),
        Switch.adaptive(value: enabled, onChanged: busy ? null : onChanged),
      ],
    ),
  );
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.memory,
    required this.onEdit,
    required this.onDelete,
  });

  final ArcMemory memory;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.midnightNavy.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.22)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                memory.title,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              onPressed: onEdit,
              tooltip: '記憶を訂正',
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              onPressed: onDelete,
              tooltip: '記憶を削除',
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        Text(
          memory.content,
          style: const TextStyle(color: AppColors.parchment, height: 1.45),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            _MetaChip(label: _memoryTypeLabel(memory.memoryType)),
            _MetaChip(label: '由来: ${_sourceLabel(memory.sourceType)}'),
            _MetaChip(
              label: memory.retentionUntil == null
                  ? '保持期限: 未設定'
                  : '保持期限: ${_dateLabel(memory.retentionUntil!)}',
            ),
          ],
        ),
      ],
    ),
  );
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.cosmicBlue.withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: const TextStyle(color: AppColors.skyBlue, fontSize: 11),
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, this.actionLabel, this.onAction});
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.midnightNavy,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        Text(message, style: const TextStyle(color: AppColors.parchment)),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('削除'),
          ),
        ],
      ),
    ) ??
    false;

void _notice(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String _dateLabel(DateTime value) =>
    '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}';

String _memoryTypeLabel(ArcMemoryType type) => switch (type) {
  ArcMemoryType.questMemory => 'Quest',
  ArcMemoryType.missionMemory => 'Mission',
  ArcMemoryType.taskMemory => 'Task',
  ArcMemoryType.trailMemory => 'Trail',
  ArcMemoryType.preferenceMemory => '好み',
  ArcMemoryType.emotionalMemory => '気持ち',
  ArcMemoryType.lifeEventMemory => '出来事',
  ArcMemoryType.arcRelationshipMemory => 'Arcとの旅',
};

String _sourceLabel(ArcMemorySourceType type) => switch (type) {
  ArcMemorySourceType.questCreated => 'Quest作成',
  ArcMemorySourceType.questUpdated => 'Quest更新',
  ArcMemorySourceType.missionCreated => 'Mission作成',
  ArcMemorySourceType.missionCompleted => 'Mission完了',
  ArcMemorySourceType.taskStarted => 'Task開始',
  ArcMemorySourceType.taskCompleted => 'Task完了',
  ArcMemorySourceType.taskRescheduled => 'Task予定変更',
  ArcMemorySourceType.trailPosted => 'Trail',
  ArcMemorySourceType.arcChat => 'Arcとの会話',
  ArcMemorySourceType.guildPost => 'Guild',
};
