import 'package:flutter/material.dart';

import '../core/persistence/persistence_sync_state.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';

class PersistenceSyncBanner extends StatelessWidget {
  const PersistenceSyncBanner({
    required this.state,
    required this.onDismiss,
    super.key,
  });

  final PersistenceSyncState state;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (!state.isActive || state.message == null) {
      return const SizedBox.shrink();
    }

    final isFailed = state.status == PersistenceSyncStatus.failed;
    final isLoading = state.status == PersistenceSyncStatus.loading;
    final color = isFailed ? Colors.redAccent : AppColors.cosmicBlue;
    final icon = isFailed
        ? Icons.error_outline
        : isLoading
        ? Icons.sync
        : Icons.check_circle_outline;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.card,
        border: Border.all(color: color.withValues(alpha: 0.36)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isFailed ? Colors.redAccent : AppColors.deepNavy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
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
