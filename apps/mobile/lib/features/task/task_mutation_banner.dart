import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import 'task_mutation_state.dart';

class TaskMutationBanner extends StatelessWidget {
  const TaskMutationBanner({
    required this.state,
    required this.onRetry,
    required this.onDiscard,
    required this.onDismiss,
    super.key,
  });

  final TaskMutationState state;
  final Future<void> Function() onRetry;
  final Future<void> Function() onDiscard;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (!state.isActive || state.message == null) {
      return const SizedBox.shrink();
    }
    final failed = state.canRetry;
    final saving = state.status == TaskMutationStatus.saving;
    final color = failed ? Colors.redAccent : AppColors.cosmicBlue;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.card,
        border: Border.all(color: color.withValues(alpha: 0.36)),
      ),
      child: Row(
        children: [
          if (saving)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(
              failed ? Icons.cloud_off_outlined : Icons.check_circle_outline,
              color: color,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.message!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (state.canRetry) ...[
            IconButton(
              onPressed: onDiscard,
              icon: const Icon(Icons.delete_outline),
              tooltip: '未送信の変更を破棄',
            ),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('再試行'),
            ),
          ] else if (!saving)
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close),
              tooltip: '閉じる',
            ),
        ],
      ),
    );
  }
}
